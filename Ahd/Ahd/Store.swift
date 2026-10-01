import Foundation
import SwiftUI

/// One pledge. `current` is what the next slip costs: it starts at `start`, and every slip is
/// paid at the current price and makes the next one `step` dearer. Clean days leave it alone.
/// A `step` of 0 makes it a fixed amount.
struct Habit: Codable, Identifiable, Equatable {
    var id: Int
    var title: String
    var start: Int
    var step: Int
    var current: Int
    /// Owed to the partner and not yet confirmed as paid.
    var owed: Int = 0
    /// Days in a row answered "I didn't".
    var cleanDays: Int = 0
    /// Weekday (1 = Sunday ... 7 = Saturday) when this one is allowed and not asked about.
    var allowedWeekday: Int?
}

struct AhdState: Codable {
    /// Who owns this phone ("barakat" / "mahmoud"); the other one gets the money.
    var me: String?
    var habits: [Habit] = []
    /// The last day whose questions were answered. Every later day up to today must be answered.
    var lastCheckedDay: Date?
    /// Daily question time (24h).
    var checkHour: Int = 21
}

@MainActor
final class Store: ObservableObject {

    nonisolated static let people: [(id: String, name: String)] = [
        ("barakat", "بركات"),
        ("mahmoud", "محمود"),
    ]
    nonisolated static func name(_ id: String) -> String {
        people.first { $0.id == id }?.name ?? id
    }

    /// Must be typed by hand to answer "no" — a tap is too easy to lie with.
    nonisolated static let cleanSentence = "والله لم أفعلها"
    /// Must be typed by hand to clear a debt.
    nonisolated static let paidSentence = "والله حولت المبلغ"
    /// Also accepted for clearing a debt.
    nonisolated static let paidSentenceAlt = "والله دفعت المبلغ"

    nonisolated static func isPaidSentence(_ typed: String) -> Bool {
        matches(typed, paidSentence) || matches(typed, paidSentenceAlt)
    }

    @Published private(set) var state: AhdState {
        didSet {
            save()
            Notifier.reschedule(self)
        }
    }
    /// Refreshed on a timer and whenever the app comes to the front.
    @Published private(set) var now = Date()

    private static let key = "ahdState"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(AhdState.self, from: data) {
            state = saved
        } else {
            state = AhdState()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    func refresh() {
        now = Date()
        Notifier.reschedule(self)
    }

    // MARK: - Derived

    var isSetUp: Bool { state.me != nil && !state.habits.isEmpty }
    var habits: [Habit] { state.habits }
    var checkHour: Int { state.checkHour }

    var partnerName: String {
        guard let me = state.me else { return "" }
        return Self.name(Self.people.first { $0.id != me }?.id ?? "")
    }
    var myName: String { state.me.map(Self.name) ?? "" }

    var totalOwed: Int { state.habits.reduce(0) { $0 + $1.owed } }

    private var cal: Calendar { Calendar.current }

    private func checkTime(on day: Date) -> Date {
        cal.date(bySettingHour: state.checkHour, minute: 0, second: 0, of: day) ?? day
    }

    /// The oldest day still waiting for an answer, or nil when everything is answered.
    var pendingDay: Date? {
        guard let last = state.lastCheckedDay,
              let next = cal.date(byAdding: .day, value: 1, to: last) else { return nil }
        return now >= checkTime(on: next) ? next : nil
    }

    /// When the next questions become due (only meaningful when nothing is pending).
    var nextCheckDate: Date? {
        guard let last = state.lastCheckedDay,
              let next = cal.date(byAdding: .day, value: 1, to: last) else { return nil }
        return checkTime(on: next)
    }

    /// Habits to ask about on `day` — a habit's allowed weekday is skipped.
    func habits(askedOn day: Date) -> [Habit] {
        let weekday = cal.component(.weekday, from: day)
        return state.habits.filter { $0.allowedWeekday != weekday }
    }

    nonisolated static func weekdayName(_ weekday: Int) -> String {
        ["الأحد", "الإثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"][(weekday - 1 + 7) % 7]
    }

    /// Alarms to set when the app goes to the background (it is cancelled whenever Ahd is opened):
    /// a debt rings every 5 minutes, unanswered questions every 3, and each upcoming question
    /// time rings every 3 minutes for 45 minutes.
    func alarmPlan(from start: Date = Date()) -> [(date: Date, title: String)] {
        var items: [(date: Date, title: String)] = []
        if totalOwed > 0 {
            for k in 0..<24 {
                items.append((start.addingTimeInterval(120 + Double(k) * 300),
                              "عليك \(totalOwed) دينار لـ\(partnerName) 💸 افتح عهد"))
            }
        } else if pendingDay != nil {
            for k in 0..<15 {
                items.append((start.addingTimeInterval(120 + Double(k) * 180),
                              "لسا ما جاوبت على أسئلة عهد 🤝"))
            }
        }
        // The next two question times still ahead.
        if var next = nextCheckDate {
            var added = 0
            while added < 2 {
                if next > start {
                    for k in 0..<15 {
                        items.append((next.addingTimeInterval(Double(k) * 180), "وقت العهد 🤝 افتح عهد وجاوب"))
                    }
                    added += 1
                }
                guard let following = cal.date(byAdding: .day, value: 1, to: next) else { break }
                next = following
            }
        }
        return items
    }

    func dayLabel(_ day: Date) -> String {
        if cal.isDateInToday(day) { return "اليوم" }
        if cal.isDateInYesterday(day) { return "مبارح" }
        return day.formatted(.dateTime.weekday(.wide).day().month().locale(Locale(identifier: "ar")))
    }

    // MARK: - Actions

    func setUp(me: String, habits: [Habit], checkHour: Int) {
        var s = AhdState()
        s.me = me
        s.habits = habits.map { var h = $0; h.current = h.start; return h }
        s.checkHour = checkHour
        // Yesterday counts as done, so the first questions come tonight.
        s.lastCheckedDay = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date()))
        state = s
    }

    /// `didIt[habit.id]` is true when the habit happened that day.
    func submit(day: Date, didIt: [Int: Bool]) {
        var s = state
        let asked = Set(habits(askedOn: day).map(\.id))
        for i in s.habits.indices {
            let id = s.habits[i].id
            guard asked.contains(id) else { continue }   // allowed day: nothing changes
            if didIt[id] == true {
                s.habits[i].owed += s.habits[i].current
                s.habits[i].current += s.habits[i].step
                s.habits[i].cleanDays = 0
            } else {
                s.habits[i].cleanDays += 1
            }
        }
        s.lastCheckedDay = cal.startOfDay(for: day)
        state = s
    }

    func markAllPaid() {
        var s = state
        for i in s.habits.indices { s.habits[i].owed = 0 }
        state = s
    }

    /// Settings edits. The running amount is not touchable — only the rules for next time.
    func update(habits edited: [Habit], checkHour: Int, me: String) {
        var s = state
        for e in edited {
            guard let i = s.habits.firstIndex(where: { $0.id == e.id }) else { continue }
            s.habits[i].title = e.title
            s.habits[i].start = e.start
            s.habits[i].step = e.step
            s.habits[i].allowedWeekday = e.allowedWeekday
            if e.step == 0 { s.habits[i].current = e.start }   // fixed amount follows its setting
        }
        s.checkHour = checkHour
        s.me = me
        state = s
    }

    // MARK: - Typed-sentence check

    /// Loose match: ignores spaces, punctuation, tashkeel and hamza/taa-marbuta spelling.
    nonisolated static func matches(_ typed: String, _ sentence: String) -> Bool {
        let t = normalize(typed)
        return !t.isEmpty && t == normalize(sentence)
    }

    nonisolated private static func normalize(_ s: String) -> String {
        var out = ""
        for ch in s.unicodeScalars {
            switch ch.value {
            case 0x064B...0x065F, 0x0670, 0x0640: continue           // tashkeel, tatweel
            case 0x0623, 0x0625, 0x0622: out.unicodeScalars.append("ا") // أ إ آ
            case 0x0649: out.unicodeScalars.append("ي")               // ى
            case 0x0629: out.unicodeScalars.append("ه")               // ة
            default:
                if CharacterSet.letters.contains(ch) { out.unicodeScalars.append(ch) }
            }
        }
        return out
    }
}
