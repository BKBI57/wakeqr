import SwiftUI

/// Amounts in dinars: whole numbers without decimals, otherwise up to 2.
func money(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...2))) + " د.أ"
}

/// Daily/monthly spending and income, plus a quick log.
struct MoneyView: View {
    @EnvironmentObject private var store: Store
    @State private var adding: Bool?   // true = income, false = expense

    var body: some View {
        List {
            Section("هالشهر") {
                row("صرفت اليوم", money(store.spentToday))
                row("صرفت هالشهر", money(store.spentThisMonth))
                row("دخلك هالشهر", money(store.incomeThisMonth))
                row("ضلّك", money(store.incomeThisMonth - store.spentThisMonth))
                    .bold()
            }

            Section("وين راحت المصاري هالشهر") {
                ForEach(Store.categories, id: \.id) { c in
                    row("\(c.icon) \(c.name)", money(store.spentThisMonth(in: c.id)))
                }
            }

            Section("السجل") {
                if store.monthEntries.isEmpty {
                    Text("لسا ما سجّلت شي هالشهر").foregroundStyle(.secondary)
                }
                ForEach(store.monthEntries) { e in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.isIncome ? "💵 دخل" : Store.categoryLabel(e.category))
                            Text(e.date.formatted(.dateTime.weekday(.abbreviated).day().hour().minute()
                                    .locale(Locale(identifier: "ar"))))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text((e.isIncome ? "+" : "−") + money(e.amount))
                            .foregroundStyle(e.isIncome ? .green : .primary)
                    }
                    .swipeActions {
                        Button("حذف", role: .destructive) { store.deleteEntry(e.id) }
                    }
                }
            }
        }
        .navigationTitle("💰 مصاريفي")
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button { adding = false } label: {
                    Label("مصروف", systemImage: "minus.circle.fill").frame(maxWidth: .infinity)
                }
                .tint(.red)
                Button { adding = true } label: {
                    Label("دخل", systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
                }
                .tint(.green)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
            .background(.bar)
        }
        .sheet(isPresented: Binding(get: { adding != nil }, set: { if !$0 { adding = nil } })) {
            AddEntryView(isIncome: adding ?? false)
                .presentationDetents([.medium])
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).monospacedDigit()
        }
    }
}

/// Amount + (for expenses) one of the categories. Three taps and done.
struct AddEntryView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    let isIncome: Bool
    @State private var text = ""
    @State private var category = Store.categories[0].id
    @FocusState private var focused: Bool

    /// Accepts Arabic digits and a comma as the decimal point.
    private var amount: Double? {
        var t = text.replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: "٫", with: ".")
        for (i, d) in "٠١٢٣٤٥٦٧٨٩".enumerated() { t = t.replacingOccurrences(of: String(d), with: String(i)) }
        guard let v = Double(t), v > 0 else { return nil }
        return v
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("المبلغ بالدينار", text: $text)
                    .keyboardType(.decimalPad)
                    .font(.title2.bold())
                    .focused($focused)
                if !isIncome {
                    Picker("التصنيف", selection: $category) {
                        ForEach(Store.categories, id: \.id) { c in
                            Text("\(c.icon) \(c.name)").tag(c.id)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(isIncome ? "💵 دخل جديد" : "مصروف جديد")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") {
                        if let amount { store.addEntry(amount: amount, isIncome: isIncome, category: category) }
                        dismiss()
                    }
                    .disabled(amount == nil)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
            }
            .onAppear { focused = true }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}
