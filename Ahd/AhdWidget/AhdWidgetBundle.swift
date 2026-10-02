import WidgetKit
import SwiftUI

#if canImport(AlarmKit)
import AlarmKit
import ActivityKit

@main
struct AhdWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 26.0, *) {
            AhdAlarmLiveActivity()
        }
    }
}

/// The Live Activity AlarmKit uses to present Ahd's alarms (lock screen + Dynamic Island).
@available(iOS 26.0, *)
struct AhdAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<AhdAlarmMetadata>.self) { _ in
            HStack(spacing: 10) {
                Image(systemName: "alarm.fill")
                    .font(.title2)
                Text("عهد — افتح التطبيق 🤝")
                    .font(.headline)
            }
            .padding()
            .activityBackgroundTint(Color.orange.opacity(0.85))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { _ in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text("عهد 🤝").font(.headline)
                }
            } compactLeading: {
                Image(systemName: "alarm.fill").foregroundStyle(.orange)
            } compactTrailing: {
                Text("🤝")
            } minimal: {
                Image(systemName: "alarm.fill").foregroundStyle(.orange)
            }
        }
    }
}

#else

@main
struct AhdWidgetBundle: WidgetBundle {
    var body: some Widget { PlaceholderWidget() }
}

/// Fallback so the extension still builds on SDKs without AlarmKit.
struct PlaceholderWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AhdPlaceholder", provider: PlaceholderProvider()) { _ in Text("عهد") }
    }
}

struct PlaceholderEntry: TimelineEntry { let date: Date }

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry { PlaceholderEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(PlaceholderEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [PlaceholderEntry(date: .now)], policy: .never))
    }
}

#endif
