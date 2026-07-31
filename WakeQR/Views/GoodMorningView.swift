import SwiftUI

struct GoodMorningView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("🌅")
                .font(.system(size: 90))

            Text("صباح الخير")
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Button("تم ✅") {
                model.backToSetup()
            }
            .font(.title3.bold())
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 0.95, green: 0.35, blue: 0.25)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }
}
