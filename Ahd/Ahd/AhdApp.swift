import SwiftUI

@main
struct AhdApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .onAppear { Notifier.requestAuthorization() }
        }
    }
}
