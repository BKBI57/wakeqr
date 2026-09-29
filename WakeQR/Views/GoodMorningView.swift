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

            // Right after your own scan is the natural moment to wake the other one.
            BuddyPanel()
                .padding(.horizontal, 28)

            if let due = model.followUpDeadline {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let now = context.date
                    let toRing = max(0, Int(due.timeIntervalSince(now)))
                    let unlocked = (model.followUpUnlockAt.map { now >= $0 }) ?? false
                    let toUnlock = max(0, Int((model.followUpUnlockAt ?? now).timeIntervalSince(now)))

                    VStack(spacing: 10) {
                        Text("يرن مجددًا بعد \(toRing / 60):\(String(format: "%02d", toRing % 60))")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(.white)

                        if unlocked {
                            Text("اضغط مطوّلًا ثانيتين لتأكيد أنك صاحٍ")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)

                            // Long press, not a tap: a tap is too easy to hit half-asleep.
                            Text("أنا صاحي — ألغِ الفحص")
                                .font(.headline.bold())
                                .foregroundStyle(Color(red: 0.9, green: 0.35, blue: 0.15))
                                .padding(.horizontal, 26)
                                .padding(.vertical, 13)
                                .background(Capsule().fill(.white))
                                .onLongPressGesture(minimumDuration: 2) {
                                    model.cancelFollowUp()
                                }
                        } else {
                            // Locked on purpose for the first couple of minutes: still being awake
                            // when it unlocks is the actual evidence that you got up.
                            Text("يفتح الإلغاء بعد \(toUnlock / 60):\(String(format: "%02d", toUnlock % 60))")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.85))

                            Label("أنا صاحي — ألغِ الفحص", systemImage: "lock.fill")
                                .font(.headline.bold())
                                .foregroundStyle(.white.opacity(0.55))
                                .padding(.horizontal, 22)
                                .padding(.vertical, 13)
                                .background(Capsule().fill(.white.opacity(0.16)))
                        }
                    }
                }
                .padding(.bottom, 34)
            } else {
                Button("تم ✅") {
                    model.backToSetup()
                }
                .font(.title3.bold())
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 0.95, green: 0.35, blue: 0.25)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }
}
