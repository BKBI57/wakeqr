import SwiftUI

struct SetAlarmView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("⏰ WakeQR")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("منبّه لا يسكت إلا بمسح رمز QR")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    if model.streak > 0 {
                        HStack(spacing: 5) {
                            Text("🔥")
                            Text("\(model.streak) \(model.streak == 1 ? "يوم" : "أيام") متتالية")
                                .font(.subheadline.bold())
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.orange.opacity(0.15)))
                        .padding(.top, 2)
                    }
                }

                DatePicker("وقت الاستيقاظ", selection: model.alarmTimeBinding, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ar"))

                VStack(spacing: 10) {
                    HStack {
                        Text("نغمة المنبّه")
                            .font(.subheadline.bold())
                        Spacer()
                        Button {
                            model.togglePreview()
                        } label: {
                            Label(model.previewing ? "إيقاف" : "تجربة",
                                  systemImage: model.previewing ? "stop.circle.fill" : "play.circle.fill")
                                .font(.subheadline.bold())
                        }
                        .tint(.orange)
                    }
                    Picker("نغمة المنبّه", selection: $model.alarmSound) {
                        ForEach(AppModel.sounds, id: \.id) { sound in
                            Text(sound.label).tag(sound.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.orange)
                }
                .padding(.horizontal, 28)

                VStack(spacing: 6) {
                    HStack {
                        Text("قوة صوت المنبّه")
                            .font(.subheadline.bold())
                        Spacer()
                        Text("\(Int(model.alarmVolume * 100))٪")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "speaker.wave.1.fill")
                            .foregroundStyle(.secondary)
                        Slider(value: $model.alarmVolume, in: 0.3...1.0, step: 0.05)
                            .tint(.indigo)
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundStyle(.secondary)
                    }
                    Text("يبدأ الرنين هادئًا ويصل لهذا المستوى خلال ٣٠ ثانية — وأزرار الصوت لن تخفضه")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)

                VStack(spacing: 6) {
                    Toggle(isOn: $model.followUpEnabled) {
                        Text("فحص الاستيقاظ بعد ٥ دقائق")
                            .font(.subheadline.bold())
                    }
                    .tint(.orange)

                    Text("بعد المسح، يرن مرة أخرى بعد ٥ دقائق إلا إذا أكّدت أنك صاحي")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)

                BuddyPanel()
                    .padding(.horizontal, 28)

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
            }
            .padding(.vertical, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}
