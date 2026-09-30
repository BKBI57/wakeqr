import Foundation
import UserNotifications

/// All reminders are local notifications, rebuilt from scratch after every change.
/// They keep coming every 15 minutes until the questions are answered or a debt is marked paid.
enum Notifier {

    static let nagSpacing: TimeInterval = 15 * 60
    /// iOS keeps at most 64 pending notifications per app.
    static let maxPending = 60

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    @MainActor
    static func reschedule(_ store: Store) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard store.isSetUp else { return }

        var items: [(date: Date, title: String, body: String)] = []
        let now = Date()

        if store.totalOwed > 0 {
            for k in 0..<36 {
                items.append((now.addingTimeInterval(60 + Double(k) * nagSpacing),
                              "عليك \(store.totalOwed) دينار لـ\(store.partnerName) 💸",
                              "ادفعها، وبعدين افتح عهد واكتب إنك دفعت."))
            }
        }

        if store.pendingDay != nil {
            for k in 0..<20 {
                items.append((now.addingTimeInterval(60 + Double(k) * nagSpacing),
                              "لسا ما جاوبت 🤝",
                              "افتح عهد وجاوب على أسئلة اليوم."))
            }
        } else if let next = store.nextCheckDate {
            // The daily repeating reminder below covers the exact time; these follow it up.
            for k in 1...12 {
                items.append((next.addingTimeInterval(Double(k) * nagSpacing),
                              "لسا ما جاوبت 🤝",
                              "افتح عهد وجاوب على أسئلة اليوم."))
            }
        }

        let cal = Calendar.current
        for (i, item) in items.prefix(maxPending).enumerated() {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: item.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: "ahd-\(i)", content: content, trigger: trigger))
        }

        // Every day at the check time, even if the app isn't opened for a while.
        let daily = UNMutableNotificationContent()
        daily.title = "وقت العهد 🤝"
        daily.body = "جاوب على سؤالين اليوم."
        daily.sound = .default
        daily.interruptionLevel = .timeSensitive
        var at = DateComponents()
        at.hour = store.checkHour
        at.minute = 0
        center.add(UNNotificationRequest(
            identifier: "ahd-daily",
            content: daily,
            trigger: UNCalendarNotificationTrigger(dateMatching: at, repeats: true)))
    }
}
