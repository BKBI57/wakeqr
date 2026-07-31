import Foundation
import SwiftUI

#if canImport(AlarmKit)
import AlarmKit

/// Plan A: a real iOS 26 system alarm via AlarmKit.
/// Every call is wrapped so that a missing entitlement / denied authorization (expected with a
/// free sideloaded Apple ID) NEVER crashes the app — we simply report failure and Plan B carries on.
enum AlarmKitBridge {

    private static let idKey = "alarmKitAlarmID"

    @MainActor
    static func scheduleDaily(hour: Int, minute: Int) async -> Bool {
        do {
            let manager = AlarmManager.shared

            switch manager.authorizationState {
            case .authorized:
                break
            case .notDetermined:
                let state = try await manager.requestAuthorization()
                guard state == .authorized else { return false }
            default:
                return false
            }

            let everyDay: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
            let schedule = Alarm.Schedule.relative(
                Alarm.Schedule.Relative(
                    time: Alarm.Schedule.Relative.Time(hour: hour, minute: minute),
                    repeats: .weekly(everyDay)
                )
            )

            // AlarmKit's system alert requires a stop button by design, so Plan A alone cannot
            // enforce "QR-only stop" — Plan B (which runs in parallel) is what enforces it.
            let stopButton = AlarmButton(text: "افتح WakeQR", textColor: .white, systemImageName: "qrcode.viewfinder")
            let alert = AlarmPresentation.Alert(title: "استيقظ! امسح رمز QR", stopButton: stopButton)
            let attributes = AlarmAttributes<WakeQRAlarmMetadata>(
                presentation: AlarmPresentation(alert: alert),
                metadata: WakeQRAlarmMetadata(),
                tintColor: Color.red
            )

            let id = UUID()
            let configuration = AlarmManager.AlarmConfiguration(schedule: schedule, attributes: attributes)
            _ = try await manager.schedule(id: id, configuration: configuration)
            UserDefaults.standard.set(id.uuidString, forKey: idKey)
            return true
        } catch {
            return false
        }
    }

    @MainActor
    static func cancel() async {
        guard let s = UserDefaults.standard.string(forKey: idKey), let id = UUID(uuidString: s) else { return }
        try? AlarmManager.shared.cancel(id: id)
        UserDefaults.standard.removeObject(forKey: idKey)
    }
}

#else

/// SDK without AlarmKit: Plan A is a no-op, Plan B does all the work.
enum AlarmKitBridge {
    static func scheduleDaily(hour: Int, minute: Int) async -> Bool { false }
    static func cancel() async {}
}

#endif
