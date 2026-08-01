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
    /// true when the iOS 26 AlarmKit system alarm was successfully authorized+scheduled (Plan A).
    @Published private(set) var alarmKitActive = false

    private let audio = AlarmAudioEngine()
    private var ticker: Timer?
    private(set) var nextFireDate: Date?

    init() {
        let d = UserDefaults.standard
        alarmHour = d.object(forKey: "alarmHour") as? Int ?? 7
        alarmMinute = d.object(forKey: "alarmMinute") as? Int ?? 0
        alarmVolume = d.object(forKey: "alarmVolume") as? Double ?? 1.0
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

    // MARK: - Sleep mode (Plan B core)

    func enterSleepMode() {
        let fire = Self.nextOccurrence(hour: alarmHour, minute: alarmMinute)
        nextFireDate = fire
        UserDefaults.standard.set(fire, forKey: "nextFireDate")

        AVCaptureDevice.requestAccess(for: .video) { _ in }   // make sure camera is usable in the morning
        audio.startKeepAlive()                                 // keeps the app alive in background
        NotificationScheduler.scheduleSafetyNet(at: fire)      // fires even if the app is killed
        UIApplication.shared.isIdleTimerDisabled = true
        phase = .sleeping
        startTicker()

        // Plan A, best effort: also register a real system alarm via AlarmKit.
        // If authorization/entitlement fails (likely with free signing) we just stay on Plan B.
        Task { [weak self] in
            guard let self else { return }
            let h = self.alarmHour, m = self.alarmMinute
            self.alarmKitActive = await AlarmKitBridge.scheduleDaily(hour: h, minute: m)
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
        audio.startAlarm(volume: Float(alarmVolume))
        phase = .ringing
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
