import SwiftUI

/// Dim, OLED-friendly screen shown while sleeping. The app must stay open (charging) —
/// the near-silent audio loop keeps it alive so the alarm can take over at fire time.
struct SleepModeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(context.date, format: .dateTime.hour().minute())
                    .font(.system(size: 72, weight: .light, design: .rounded))
                    .foregroundStyle(Color(white: 0.85))
                    .monospacedDigit()
            }

            HStack(spacing: 6) {
                Image(systemName: "alarm")
                Text("المنبّه: \(model.alarmTimeText)")
            }
            .font(.title3)
            .foregroundStyle(Color(white: 0.6))

            Text("اترك التطبيق مفتوحًا والشاحن موصولًا 🔌")
                .font(.subheadline)
                .foregroundStyle(Color(white: 0.5))

            Spacer()

            Button("إلغاء وضع النوم") {
                model.cancelSleepMode()
            }
            .font(.footnote)
            .foregroundStyle(Color(white: 0.45))
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .statusBarHidden()
    }
}
