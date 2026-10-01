import SwiftUI

struct SetupView: View {
    @EnvironmentObject private var store: Store
    @State private var me: String?
    @State private var habits: [Habit] = [
        Habit(id: 1, title: "العهد الأول", start: 5, step: 2, current: 5),
        Habit(id: 2, title: "الأكل الجاهز من برّا", start: 1, step: 0, current: 1, allowedWeekday: 2),
    ]
    @State private var checkHour = 21

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("كل يوم الساعة \(hourText(checkHour)) التلفون بيرن لحتى تفتح عهد وتجاوب. إذا عملتها بتدفع المبلغ لصاحبك، والمرة الجاية بيصير أغلى.")
                        .font(.subheadline)
                }

                Section("مين أنت؟") {
                    Picker("أنا", selection: $me) {
                        Text("اختار").tag(String?.none)
                        ForEach(Store.people, id: \.id) { p in
                            Text(p.name).tag(Optional(p.id))
                        }
                    }
                    .pickerStyle(.segmented)
                }

                ForEach($habits) { $habit in
                    HabitEditor(habit: $habit, number: habit.id)
                }

                Section("وقت السؤال اليومي") {
                    Stepper("الساعة \(hourText(checkHour))", value: $checkHour, in: 0...23)
                }

                Section {
                    Button {
                        if let me { store.setUp(me: me, habits: habits, checkHour: checkHour) }
                    } label: {
                        Text("ابدأ العهد 🤝")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(me == nil)
                }
            }
            .navigationTitle("عهد")
        }
    }
}

/// Title, starting amount and daily increase for one pledge (setup and settings).
struct HabitEditor: View {
    @Binding var habit: Habit
    let number: Int

    var body: some View {
        Section("العهد \(number)") {
            TextField("الاسم (ما حدا بيشوفه غيرك)", text: $habit.title)
            if habit.allowedWeekday != nil {
                // Fixed amount, with one allowed day a week.
                Stepper("مبلغ ثابت: \(habit.start) دينار", value: $habit.start, in: 1...500)
                Picker("اليوم المسموح", selection: Binding(
                    get: { habit.allowedWeekday ?? 2 },
                    set: { habit.allowedWeekday = $0 })) {
                    ForEach(1...7, id: \.self) { d in
                        Text(Store.weekdayName(d)).tag(d)
                    }
                }
            } else {
                Stepper("بيبدأ بـ \(habit.start) دينار", value: $habit.start, in: 1...500)
                Stepper("بيزيد \(habit.step) دينار كل مرة بتعملها", value: $habit.step, in: 1...100)
            }
        }
    }
}

func hourText(_ hour: Int) -> String {
    let h12 = hour % 12 == 0 ? 12 : hour % 12
    let part = hour < 12 ? "الصبح" : (hour < 17 ? "الظهر" : "بالليل")
    return "\(h12) \(part)"
}
