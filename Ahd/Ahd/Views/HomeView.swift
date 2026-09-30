import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: Store
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(store.habits) { habit in
                        Card {
                            Text(habit.title)
                                .font(.headline)
                            HStack(alignment: .firstTextBaseline) {
                                Text("\(habit.current)")
                                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                                Text("دينار")
                                    .font(.title3.bold())
                            }
                            Text(habit.step > 0
                                 ? "لو عملتها، هاد يلي رح تدفعه لـ\(store.partnerName). بكرا بيصير \(habit.current + habit.step)."
                                 : "مبلغ ثابت، بتدفعه لـ\(store.partnerName) إذا عملتها.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            if let d = habit.allowedWeekday {
                                Text("مسموح يوم \(Store.weekdayName(d)) بس 🍽️")
                                    .font(.footnote.bold())
                            }
                            if habit.cleanDays > 0 {
                                Text("🔥 \(habit.cleanDays) \(habit.cleanDays == 1 ? "يوم" : "أيام") ملتزم")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    if let next = store.nextCheckDate {
                        Text("السؤال الجاي: \(store.dayLabel(next)) الساعة \(hourText(store.checkHour))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .navigationTitle("عهد 🤝")
            .toolbar {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var habits: [Habit] = []
    @State private var checkHour = 21
    @State private var me = "barakat"

    var body: some View {
        NavigationStack {
            Form {
                Section("مين أنت؟") {
                    Picker("أنا", selection: $me) {
                        ForEach(Store.people, id: \.id) { p in
                            Text(p.name).tag(p.id)
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
                    Text("التغيير بيمشي على القواعد بس. المبلغ الحالي ما بيتغيّر.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("الإعدادات")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") {
                        store.update(habits: habits, checkHour: checkHour, me: me)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
            }
            .onAppear {
                habits = store.habits
                checkHour = store.checkHour
                me = store.state.me ?? "barakat"
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}
