import SwiftUI

struct GoodMorningView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("🌅")
                .font(.system(size: 76))

            Text("صباح الخير")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            if model.streak > 0 {
                HStack(spacing: 6) {
                    Text("🔥")
                    Text("\(model.streak) \(model.streak == 1 ? "يوم" : "أيام") متتالية")
                        .font(.headline.bold())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Capsule().fill(.white.opacity(0.22)))
            }

            // The scan is done; the risk now is walking back to bed. Say something about that.
            Text(model.morningMessage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 20).fill(.black.opacity(0.22)))
                .padding(.horizontal, 22)
                .padding(.top, 6)

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
