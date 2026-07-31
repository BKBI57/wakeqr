import WidgetKit
import SwiftUI

@main
struct WakeQRWidgetBundle: WidgetBundle {
    var body: some Widget {
        #if canImport(AlarmKit)
        AlarmLiveActivity()
        #else
        PlaceholderWidget()
        #endif
    }
}

#if !canImport(AlarmKit)
/// Fallback so the extension still builds on SDKs without AlarmKit.
struct PlaceholderWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WakeQRPlaceholder", provider: PlaceholderProvider()) { _ in
            Text("WakeQR")
        }
        .configurationDisplayName("WakeQR")
        .description("WakeQR")
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
