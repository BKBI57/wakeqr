import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            switch model.phase {
            case .setup:
                SetAlarmView()
            case .sleeping:
                SleepModeView()
            case .ringing:
                RingingView()
            case .goodMorning:
                GoodMorningView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: phaseKey)
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var phaseKey: Int {
        switch model.phase {
        case .setup: 0
        case .sleeping: 1
        case .ringing: 2
        case .goodMorning: 3
        }
    }
}
