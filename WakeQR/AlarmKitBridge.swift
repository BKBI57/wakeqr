import Foundation

#if canImport(AlarmKit)
import AlarmKit

/// Cleanup-only shim.
///
/// WakeQR used to register a real iOS 26 system alarm here as a "Plan A" backup. It was removed:
/// the alarm repeated daily forever, and every new sleep-mode session scheduled another one with a
/// fresh UUID while overwriting the stored ID — so old alarms were orphaned and kept firing with no
/// way for the app to reach them. Ringing is now owned entirely by the app (Plan B) plus the local
/// notification safety net.
///
/// `cancel()` stays so an app that still has an ID on record clears it on next launch.
enum AlarmKitBridge {

    private static let idKey = "alarmKitAlarmID"

    @MainActor
    static func cancel() async {
        guard let s = UserDefaults.standard.string(forKey: idKey), let id = UUID(uuidString: s) else { return }
        // AlarmKit exists only on iOS 26+; older phones never had an alarm to clean up.
        if #available(iOS 26.0, *) {
            try? AlarmManager.shared.cancel(id: id)
        }
        UserDefaults.standard.removeObject(forKey: idKey)
    }
}

#else

/// SDK without AlarmKit: nothing to clean up.
enum AlarmKitBridge {
    static func cancel() async {}
}

#endif
