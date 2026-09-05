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
    /// How long after a successful scan the follow-up check fires.
    static let followUpDelay: TimeInterval = 5 * 60
    /// Cancelling is locked until this long after the scan. Standing at the QR seconds after
    /// stopping the alarm is the worst moment to be trusted with a cancel button; being awake
    /// two minutes later is real evidence you got up.
    static let followUpUnlockDelay: TimeInterval = 2 * 60

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
        ("alarm_urgent", "إنذار"),
        ("alarm_buzzer", "أزيز"),
        ("alarm_chime", "تدرّج"),
    ]
    /// true while a tone preview is playing on the setup screen.
    @Published private(set) var previewing = false
    /// Consecutive days the alarm was stopped by scanning the QR code.
    @Published private(set) var streak: Int
    /// Re-checks that you actually stayed up, a few minutes after the first scan.
    @Published var followUpEnabled: Bool {
        didSet { UserDefaults.standard.set(followUpEnabled, forKey: "followUpEnabled") }
    }
    /// When the follow-up check will fire; nil when nothing is pending.
    @Published private(set) var followUpDeadline: Date?
    /// Cancelling only becomes possible at this moment.
    @Published private(set) var followUpUnlockAt: Date?
    /// true while the current ring is the follow-up rather than the morning alarm.
    @Published private(set) var isFollowUpRing = false

    /// Shown on the good-morning screen. The point is the minutes right after the scan —
    /// standing in the bathroom having already scanned is exactly when going back to bed happens.
    static let morningMessages: [String] = [
        "قمت من السرير فعلًا. أصعب جزء خلص — لا ترجع له.",
        "«خمس دقائق بس» هي الجملة اللي بتضيّع الصبح كله.",
        "صلّ الفجر أولًا. بعدها قرّر إذا بدك ترجع تنام.",
        "الرجوع للفراش الآن بيلغي كل اللي عملته قبل شوي.",
        "اشرب كوب ماء الآن — الجسم بيصحى بالماء، مش بالنيّة.",
        "أول عشر دقائق هي المعركة كلها. اصمد فيها وبعدها بتسهل.",
        "لا تجلس على طرف السرير. اطلع من الغرفة.",
        "افتح الشبّاك وخلّي الضوء يدخل — الضوء بيوقف هرمون النوم.",
        "النوم بعد الفجر بيسرق طاقة اليوم كله، مش بس ساعة.",
        "الشخص اللي بدك تصير إياه — واقف هلق، مش نايم.",
        "ما في نسخة أفضل منك بتبدأ يومها الساعة عشرة.",
        "حرّك جسمك دقيقة وحدة. الحركة بتقتل النعاس أسرع من أي شي.",
        "لو رجعت نمت هلق، بكرا بتلوم حالك — وأنت بتعرف.",
        "الصبح هدوء ما بتلاقيه بباقي اليوم. لا تضيّعه.",
        "أنت صحيت. خلّيها تعني شي.",
        "اغسل وجهك بماء بارد قبل ما تفكر بأي شي تاني.",
        "قرار واحد بيفرق: تطلع من الغرفة، أو ترجع للسرير.",
        "التعب اللي حاسّه هلق بيروح خلال ربع ساعة. النوم بيرجّعه أثقل.",
        "لا تفتح التلفون وأنت واقف. اعمل شي بجسمك أول.",
        "يومك بدأ. مبروك — كمّل.",
    ]

    /// Rotates once per calendar day so the message is different each morning.
    var morningMessage: String {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return Self.morningMessages[day % Self.morningMessages.count]
    }

    private let audio = AlarmAudioEngine()
    private var ticker: Timer?
    private(set) var nextFireDate: Date?

    init() {
        let d = UserDefaults.standard
        alarmHour = d.object(forKey: "alarmHour") as? Int ?? 7
        alarmMinute = d.object(forKey: "alarmMinute") as? Int ?? 0
        alarmVolume = d.object(forKey: "alarmVolume") as? Double ?? 1.0
        alarmSound = d.string(forKey: "alarmSound") ?? "alarm_classic"
        streak = d.object(forKey: "streak") as? Int ?? 0
        followUpEnabled = d.object(forKey: "followUpEnabled") as? Bool ?? true
    }

    /// Called once at launch.
    func bootstrap() {
        NotificationScheduler.requestAuthorization()
        // Plan A (AlarmKit) was removed: it repeated daily forever and every new sleep-mode
        // session leaked another one. Clear whatever ID we still have on record.
        Task { await AlarmKitBridge.cancel() }

        // A pending follow-up check outlives a force-quit: resume or fire it.
        if let due = UserDefaults.standard.object(forKey: "followUpDeadline") as? Date {
            if Date() >= due {
                if Date() < due.addingTimeInterval(Self.ringingWindow) {
                    startFollowUpRing()
                } else {
                    clearFollowUp()   // too late to be useful; drop it
                }
            } else {
                followUpDeadline = due
                followUpUnlockAt = UserDefaults.standard.object(forKey: "followUpUnlockAt") as? Date
                phase = .goodMorning
                startFollowUpTimer()
            }
            return
        }
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
        isFollowUpRing = false
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
        let wasFollowUp = isFollowUpRing
        recordWake()
        stopEverything()
        phase = .goodMorning
        // Arm the check only after the morning alarm. Scanning the follow-up itself ends the day —
        // otherwise it would loop every five minutes forever.
        if followUpEnabled && !wasFollowUp { armFollowUp() }
        return true
    }

    // MARK: - Follow-up check

    /// Schedules the "are you still up?" ring. Cancelling it is a deliberate act (see the
    /// good-morning screen) because the app cannot tell being awake from having gone back to bed.
    private func armFollowUp() {
        let now = Date()
        let due = now.addingTimeInterval(Self.followUpDelay)
        let unlock = now.addingTimeInterval(Self.followUpUnlockDelay)
        followUpDeadline = due
        followUpUnlockAt = unlock
        UserDefaults.standard.set(due, forKey: "followUpDeadline")
        UserDefaults.standard.set(unlock, forKey: "followUpUnlockAt")
        // Safety net first: it clears pending requests, so the reminder has to be added after it.
        NotificationScheduler.scheduleSafetyNet(at: due, sound: alarmSound)
        let minutesLeft = Int((Self.followUpDelay - Self.followUpUnlockDelay) / 60)
        NotificationScheduler.scheduleFollowUpReminder(at: unlock, minutesLeft: minutesLeft)
        startFollowUpTimer()
    }

    /// false while the cancel button is still locked.
    var canCancelFollowUp: Bool {
        guard let unlock = followUpUnlockAt else { return false }
        return Date() >= unlock
    }

    private func startFollowUpTimer() {
        ticker?.invalidate()
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let due = self.followUpDeadline, self.phase == .goodMorning else { return }
                if Date() >= due { self.startFollowUpRing() }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    /// Called when you confirm you are actually up. Refused while still locked.
    func cancelFollowUp() {
        guard canCancelFollowUp else { return }
        clearFollowUp()
        NotificationScheduler.cancelAll()
    }

    private func clearFollowUp() {
        ticker?.invalidate()
        followUpDeadline = nil
        followUpUnlockAt = nil
        UserDefaults.standard.removeObject(forKey: "followUpDeadline")
        UserDefaults.standard.removeObject(forKey: "followUpUnlockAt")
    }

    private func startFollowUpRing() {
        clearFollowUp()
        isFollowUpRing = true
        UIApplication.shared.isIdleTimerDisabled = true
        audio.startAlarm(soundNamed: alarmSound, volume: Float(alarmVolume))
        phase = .ringing
        NotificationScheduler.scheduleSafetyNet(at: Date().addingTimeInterval(90), sound: alarmSound)
    }

    /// Extends the streak on the first successful scan of a calendar day; a skipped day resets it.
    private func recordWake() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let d = UserDefaults.standard

        if let last = d.object(forKey: "lastWakeDay") as? Date {
            let lastDay = cal.startOfDay(for: last)
            guard lastDay != today else { return }   // already counted this morning
            let gap = cal.dateComponents([.day], from: lastDay, to: today).day ?? .max
            streak = (gap == 1) ? streak + 1 : 1
        } else {
            streak = 1
        }
        d.set(streak, forKey: "streak")
        d.set(today, forKey: "lastWakeDay")
    }

    func backToSetup() {
        cancelFollowUp()
        phase = .setup
    }

    private func stopEverything() {
        ticker?.invalidate()
        isFollowUpRing = false
        audio.stopAll()
        NotificationScheduler.cancelAll()
        UIApplication.shared.isIdleTimerDisabled = false
        nextFireDate = nil
        UserDefaults.standard.removeObject(forKey: "nextFireDate")
        Task { await AlarmKitBridge.cancel() }
    }
}
