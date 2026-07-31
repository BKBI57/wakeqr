#if canImport(AlarmKit)
import AlarmKit

/// Empty metadata attached to the AlarmKit alarm / Live Activity. Shared between app and widget.
struct WakeQRAlarmMetadata: AlarmMetadata {
    init() {}
}
#endif
