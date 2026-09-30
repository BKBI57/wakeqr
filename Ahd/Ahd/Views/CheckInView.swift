import SwiftUI

/// The daily questions for one day. "No" has to be typed as a full sentence; "yes" is one tap.
struct CheckInView: View {
    @EnvironmentObject private var store: Store
    let day: Date
    @State private var answers: [Int: Bool] = [:]
    @State private var typed: [Int: String] = [:]

    private var ready: Bool {
        store.habits.allSatisfy { h in
            switch answers[h.id] {
            case true?: return true
            case false?: return Store.matches(typed[h.id] ?? "", Store.cleanSentence)
            case nil: return false
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("🤝 أسئلة \(store.dayLabel(day))")
                    .font(.title.bold())
                    .padding(.top, 24)

                ForEach(store.habits) { habit in
                    Card {
                        Text("\(habit.title): هل عملتها \(store.dayLabel(day))؟")
                            .font(.headline)

                        HStack(spacing: 10) {
                            choice("لا، ما عملتها", selected: answers[habit.id] == false, tint: .green) {
                                answers[habit.id] = false
                            }
                            choice("نعم، عملتها", selected: answers[habit.id] == true, tint: .red) {
                                answers[habit.id] = true
                            }
                        }

                        if answers[habit.id] == false {
                            SentenceField(sentence: Store.cleanSentence, text: Binding(
                                get: { typed[habit.id] ?? "" },
                                set: { typed[habit.id] = $0 }))
                            Text("المبلغ بيصير \(habit.current + habit.step) دينار 📈")
                                .font(.footnote.bold())
                                .foregroundStyle(.green)
                        } else if answers[habit.id] == true {
                            Text("رح يصير عليك \(habit.current) دينار لـ\(store.partnerName)")
                                .font(.footnote.bold())
                                .foregroundStyle(.red)
                        }
                    }
                }

                Button {
                    store.submit(day: day, didIt: answers)
                } label: {
                    Text("سجّل")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!ready)

                Text("كون صادق مع حالك — ما حدا بيشوف هالشاشة غيرك.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }

    private func choice(_ label: String, selected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12)
                    .fill(selected ? tint.opacity(0.35) : Color.white.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(selected ? tint : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}
