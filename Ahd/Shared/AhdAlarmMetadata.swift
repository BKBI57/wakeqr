#if canImport(AlarmKit)
import AlarmKit

/// Empty metadata attached to Ahd's alarms. Shared between the app and the widget extension.
struct AhdAlarmMetadata: AlarmMetadata {
    init() {}
}
#endif
