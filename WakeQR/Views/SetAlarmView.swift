import SwiftUI

struct SetAlarmView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 8) {
                Text("⏰ WakeQR")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text("منبّه لا يسكت إلا بمسح رمز QR")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            DatePicker("وقت الاستيقاظ", selection: model.alarmTimeBinding, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "ar"))

            Button {
                model.enterSleepMode()
            } label: {
                Label("ابدأ وضع النوم", systemImage: "moon.zzz.fill")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .padding(.horizontal, 24)

            VStack(spacing: 6) {
                Text("قبل النوم: افتح وضع النوم، وصّل الشاحن، واترك التطبيق مفتوحًا")
                Text("الإيقاف صباحًا فقط بمسح رمز QR المطبوع")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}
