#if canImport(AlarmKit)
import WidgetKit
import SwiftUI
import AlarmKit
import ActivityKit

/// The Live Activity AlarmKit requires to present the alarm (lock screen + Dynamic Island).
struct AlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<WakeQRAlarmMetadata>.self) { context in
            HStack(spacing: 10) {
                Image(systemName: "alarm.fill")
                    .font(.title2)
                Text("WakeQR — امسح رمز QR للإيقاف")
                    .font(.headline)
            }
            .padding()
            .activityBackgroundTint(Color.red.opacity(0.85))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 8) {
                        Image(systemName: "alarm.fill")
                        Text("WakeQR")
                            .font(.headline)
                    }
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(.red)
            } compactTrailing: {
                Image(systemName: "qrcode.viewfinder")
            } minimal: {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(.red)
            }
        }
    }
}
#endif
