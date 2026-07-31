import Foundation
import UserNotifications

/// Safety net for Plan B: if the app gets killed before the alarm, ~60 stacked local
/// notifications (the iOS pending limit is 64) still fire with sound, 2 seconds apart.
enum NotificationScheduler {

    static let count = 60
    static let spacing: TimeInterval = 2

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

        let cal = Calendar.current
        for i in 0..<count {
            let date = fireDate.addingTimeInterval(Double(i) * spacing)
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
