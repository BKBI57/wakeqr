#if canImport(AlarmKit)
import AlarmKit

/// Empty metadata attached to Ahd's alarms. Shared between the app and the widget extension.
@available(iOS 26.0, *)
struct AhdAlarmMetadata: AlarmMetadata {
    init() {}
}
#endif
