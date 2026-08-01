import Foundation
import UserNotifications

/// Safety net for Plan B: if the app gets killed before the alarm, ~60 stacked local
/// notifications (the iOS pending limit is 64) still fire with sound.
/// Escalating schedule: a rapid burst first (every 2s), then sustained fire every 45s,
/// covering about 32 minutes — dismissing one notification never stops the next.
enum NotificationScheduler {

    static let burstCount = 20
    static let burstSpacing: TimeInterval = 2
    static let sustainCount = 40
    static let sustainSpacing: TimeInterval = 45

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func scheduleSafetyNet(at fireDate: Date) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let content = UNMutableNotificationContent()
        content.title = "استيقظ! ⏰"
        content.body = "افتح WakeQR وامسح رمز QR لإيقاف المنبه"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("alarm.wav"))
        content.interruptionLevel = .timeSensitive

        var offsets: [TimeInterval] = []
        for i in 0..<burstCount { offsets.append(Double(i) * burstSpacing) }
        let burstEnd = Double(burstCount) * burstSpacing
        for i in 0..<sustainCount { offsets.append(burstEnd + Double(i + 1) * sustainSpacing) }

        let cal = Calendar.current
        for (i, offset) in offsets.enumerated() {
            let date = fireDate.addingTimeInterval(offset)
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: "wakeqr-net-\(i)", content: content, trigger: trigger)
            center.add(request)
        }
    }

    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}
