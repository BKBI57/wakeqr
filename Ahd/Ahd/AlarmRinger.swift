import Foundation
import SwiftUI

#if canImport(AlarmKit)
import AlarmKit

/// Real system alarms (iOS 26 AlarmKit): they ring through silent mode and Focus like the Clock app.
/// The system alert always has a stop button, so instead of one endless ring we schedule a chain of
/// one-shot alarms a few minutes apart — stopping one only buys a few minutes. Opening Ahd cancels
/// the chain; leaving with something unanswered or unpaid starts a new one.
/// Every alarm is one-shot and its id is stored, so nothing outlives a reschedule (the daily
/// repeating alarm that leaked in WakeQR v1 is exactly what this avoids).
/// AlarmKit is iOS 26+; on older phones these do nothing and the local notifications remain.
enum AlarmRinger {

    private static let idsKey = "ahdAlarmIDs"
    /// Bumped by every cancel, so a schedule still running in the background stops adding alarms.
    @MainActor private static var generation = 0

    /// Asks for permission. Call while the app is on screen — the prompt can't show from the background.
    @MainActor
    static func authorize() async {
        guard #available(iOS 26.0, *) else { return }
        if AlarmManager.shared.authorizationState == .notDetermined {
            _ = try? await AlarmManager.shared.requestAuthorization()
        }
    }

    @MainActor
    static func cancelAll() {
        generation += 1
        guard #available(iOS 26.0, *) else { return }
        for s in UserDefaults.standard.stringArray(forKey: idsKey) ?? [] {
            if let id = UUID(uuidString: s) { try? AlarmManager.shared.cancel(id: id) }
        }
        UserDefaults.standard.removeObject(forKey: idsKey)
    }

    @MainActor
    static func schedule(_ items: [(date: Date, title: String)]) async {
        cancelAll()
        let gen = generation
        guard #available(iOS 26.0, *),
              AlarmManager.shared.authorizationState == .authorized else { return }

        var ids: [String] = []
        for item in items where item.date > Date() {
            let stop = AlarmButton(text: "افتح عهد", textColor: .white, systemImageName: "hand.raised.fill")
            let alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: item.title),
                                                stopButton: stop)
            let attributes = AlarmAttributes<AhdAlarmMetadata>(
                presentation: AlarmPresentation(alert: alert),
                metadata: AhdAlarmMetadata(),
                tintColor: Color.orange
            )
            let id = UUID()
            let configuration = AlarmManager.AlarmConfiguration(schedule: .fixed(item.date), attributes: attributes)
            guard (try? await AlarmManager.shared.schedule(id: id, configuration: configuration)) != nil else { continue }
            // The app came back to the front meanwhile: drop this one and stop.
            guard gen == generation else {
                try? AlarmManager.shared.cancel(id: id)
                return
            }
            ids.append(id.uuidString)
            UserDefaults.standard.set(ids, forKey: idsKey)
        }
    }
}

#else

/// SDK without AlarmKit: the local notifications are all there is.
enum AlarmRinger {
    static func authorize() async {}
    static func cancelAll() {}
    static func schedule(_ items: [(date: Date, title: String)]) async {}
}

#endif
