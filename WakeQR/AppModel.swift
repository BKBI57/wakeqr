import Foundation
import SwiftUI
import AVFoundation

/// Central state machine. Phases:
/// setup -> sleeping (Sleep Mode, app kept alive by audio) -> ringing (QR-only stop) -> goodMorning
@MainActor
final class AppModel: ObservableObject {

    enum Phase { case setup, sleeping, ringing, goodMorning }

    /// The ONLY payload that stops the alarm.
    static let qrPayload = "WAKE_UP_BKBI"
    /// If the app is relaunched within this window after fire time, it goes straight to ringing.
    static let ringingWindow: TimeInterval = 45 * 60

    @Published private(set) var phase: Phase = .setup
    @Published var alarmHour: Int {
        didSet { UserDefaults.standard.set(alarmHour, forKey: "alarmHour") }
    }
    @Published var alarmMinute: Int {
        didSet { UserDefaults.standard.set(alarmMinute, forKey: "alarmMinute") }
    }
    /// Alarm loudness (0.3 ... 1.0). Applied to the player AND pushed to the system volume while ringing.
    @Published var alarmVolume: Double {
        didSet { UserDefaults.standard.set(alarmVolume, forKey: "alarmVolume") }
    }
    /// Selected alarm tone (base name of a bundled wav, no extension).
    @Published var alarmSound: String {
        didSet { UserDefaults.standard.set(alarmSound, forKey: "alarmSound") }
    }

    /// Bundled tones: (file base name, Arabic label).
    static let sounds: [(id: String, label: String)] = [
        ("alarm_classic", "كلاسيكي"),
        ("alarm_siren", "سارينة"),
        ("alarm_bell", "جرس"),
        ("alarm_digital", "ديجيتال"),
    ]
    /// true when the iOS 26 AlarmKit system alarm was successfully authorized+scheduled (Plan A).
    @Published private(set) var alarmKitActive = false
    /// true while a tone preview is playing on the setup screen.
    @Published private(set) var previewing = false

    private let audio = AlarmAudioEngine()
    private var ticker: Timer?
    private(set) var nextFireDate: Date?

    init() {
        let d = UserDefaults.standard
        alarmHour = d.object(forKey: "alarmHour") as? Int ?? 7
        alarmMinute = d.object(forKey: "alarmMinute") as? Int ?? 0
        alarmVolume = d.object(forKey: "alarmVolume") as? Double ?? 1.0
        alarmSound = d.string(forKey: "alarmSound") ?? "alarm_classic"
    }

    /// Called once at launch.
    func bootstrap() {
        NotificationScheduler.requestAuthorization()
        // If we were killed while an alarm was due, resume ringing immediately.
        if let fire = UserDefaults.standard.object(forKey: "nextFireDate") as? Date,
           Date() >= fire, Date() < fire.addingTimeInterval(Self.ringingWindow) {
            nextFireDate = fire
            startRinging()
        }
    }

    /// Binding for the wheel picker on the setup screen.
    var alarmTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: self.alarmHour, minute: self.alarmMinute, second: 0, of: Date()) ?? Date()
            },
            set: { newValue in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                self.alarmHour = c.hour ?? 7
                self.alarmMinute = c.minute ?? 0
            }
        )
    }

    var alarmTimeText: String {
        String(format: "%02d:%02d", alarmHour, alarmMinute)
    }

    static func nextOccurrence(hour: Int, minute: Int, after date: Date = Date()) -> Date {
        let cal = Calendar.current
        var c = DateComponents()
        c.hour = hour
        c.minute = minute
        c.second = 0
        return cal.nextDate(after: date, matching: c, matchingPolicy: .nextTime) ?? date.addingTimeInterval(60)
    }

    /// Play/stop a short preview of the currently selected tone (setup screen).
    func togglePreview() {
        previewing = audio.togglePreview(soundNamed: alarmSound, volume: Float(alarmVolume))
    }

    // MARK: - Sleep mode (Plan B core)

    func enterSleepMode() {
        audio.stopPreview()
        previewing = false
        let fire = Self.nextOccurrence(hour: alarmHour, minute: alarmMinute)
        nextFireDate = fire
        UserDefaults.standard.set(fire, forKey: "nextFireDate")

        AVCaptureDevice.requestAccess(for: .video) { _ in }   // make sure camera is usable in the morning
        audio.startKeepAlive()                                 // keeps the app alive in background
        NotificationScheduler.scheduleSafetyNet(at: fire, sound: alarmSound) // fires even if the app is killed
        UIApplication.shared.isIdleTimerDisabled = true
        phase = .sleeping
        startTicker()

        // Plan A, best effort: also register a real AlarmKit system alarm — but 3 minutes AFTER
        // the in-app alarm. It is a backup for the killed-app case only; its mandatory X (stop)
        // button must never be the thing that silences the real ringing. If the QR is scanned
        // within those 3 minutes it gets cancelled and never fires.
        let backup = fire.addingTimeInterval(3 * 60)
        let bc = Calendar.current.dateComponents([.hour, .minute], from: backup)
        Task { [weak self] in
            guard let self else { return }
            self.alarmKitActive = await AlarmKitBridge.scheduleDaily(hour: bc.hour ?? 0, minute: bc.minute ?? 0)
        }
    }

    /// Leaving sleep mode is only allowed BEFORE the alarm fires.
    func cancelSleepMode() {
        guard phase == .sleeping else { return }
        stopEverything()
        phase = .setup
    }

    private func startTicker() {
        ticker?.invalidate()
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.phase == .sleeping, let fire = self.nextFireDate else { return }
                if Date() >= fire { self.startRinging() }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    // MARK: - Ringing

    private func startRinging() {
        ticker?.invalidate()
        UIApplication.shared.isIdleTimerDisabled = true
        audio.startAlarm(soundNamed: alarmSound, volume: Float(alarmVolume))
        phase = .ringing
        // The app itself is now the alarm, so push the notification safety net 90s into the
        // future: no notification sounds stacking on top of the ringing (the noise-mush issue),
        // but if the app gets force-quit the net still kicks in within a minute and a half.
        NotificationScheduler.scheduleSafetyNet(at: Date().addingTimeInterval(90), sound: alarmSound)
    }

    /// Returns true only for the correct payload; the alarm keeps ringing otherwise.
    func handleScannedCode(_ code: String) -> Bool {
        guard code == Self.qrPayload else { return false }
        stopEverything()
        phase = .goodMorning
        return true
    }

    func backToSetup() {
        phase = .setup
    }

    private func stopEverything() {
        ticker?.invalidate()
        audio.stopAll()
        NotificationScheduler.cancelAll()
        UIApplication.shared.isIdleTimerDisabled = false
        nextFireDate = nil
        UserDefaults.standard.removeObject(forKey: "nextFireDate")
        Task { await AlarmKitBridge.cancel() }
        alarmKitActive = false
    }
}
