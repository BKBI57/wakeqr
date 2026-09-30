import SwiftUI

/// Blocks the whole app while a debt is open. Reminders keep coming every 15 minutes
/// until "paid" is typed here.
struct PayView: View {
    @EnvironmentObject private var store: Store
    @State private var typed = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("💸")
                    .font(.system(size: 70))
                    .padding(.top, 40)

                Text("عليك \(store.totalOwed) دينار")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                Text("لـ\(store.partnerName)")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)

                Card {
                    ForEach(store.habits.filter { $0.owed > 0 }) { habit in
                        HStack {
                            Text(habit.title)
                            Spacer()
                            Text("\(habit.owed) دينار").bold()
                        }
                    }
                }

                Card {
                    Text("العهد عهد. ادفع المبلغ لـ\(store.partnerName)، وبعدها اكتب هون.")
                        .font(.subheadline)
                    SentenceField(sentence: Store.paidSentence, text: $typed)
                    Button {
                        store.markAllPaid()
                    } label: {
                        Text("دفعت ✅")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(!Store.matches(typed, Store.paidSentence))
                }

                Text("الإشعارات رح تضل توصلك كل ربع ساعة لحتى تكتب إنك دفعت.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }
}
