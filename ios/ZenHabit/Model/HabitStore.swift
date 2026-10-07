import Foundation
import Observation

/// What the "Velocity Visualizer" draws: one cell per day for the last 90 days plus today.
struct Heatmap {
    struct Cell: Identifiable, Equatable {
        /// Position in the grid, 0 = oldest day, last = today.
        let id: Int
        let date: Date
        let count: Int
        let level: Int
        let isToday: Bool
    }

    let cells: [Cell]
    let activeDays: Int
    /// How many habits each cell is out of (1 when a single habit is selected).
    let total: Int
    /// The habit the heatmap is filtered to, or nil for all habits.
    let selectedHabit: Habit?

    /// Intensity 0–4 from the share of habits done that day.
    static func level(count: Int, total: Int) -> Int {
        guard total > 0, count > 0 else { return 0 }
        let ratio = Double(count) / Double(total)
        if ratio <= 0.25 { return 1 }
        if ratio <= 0.5 { return 2 }
        if ratio <= 0.75 { return 3 }
        return 4
    }
}

/// Owns the habits, saves them, and answers every "how am I doing" question the UI asks.
@Observable
final class HabitStore {
    static let allFilter = "all"
    /// Same key the web app uses in localStorage.
    static let storageKey = "zenhabits_state_vanilla"

    private(set) var habits: [Habit]
    /// "all" or the id of the habit the heatmap is showing.
    var heatmapFilter: String = HabitStore.allFilter
    /// The moment "today" is measured from. Refreshed when the day rolls over.
    private(set) var now: Date

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current, now: Date = Date()) {
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
        self.habits = HabitStore.load(from: defaults)
    }

    // MARK: - Persistence

    private struct SavedState: Codable {
        var habits: [Habit]
    }

    private static func load(from defaults: UserDefaults) -> [Habit] {
        guard let stored = defaults.object(forKey: storageKey) else { return Habit.seeds }
        guard let json = jsonData(from: stored),
              let state = try? JSONDecoder().decode(SavedState.self, from: json) else { return [] }
        return state.habits
    }

    /// The web app stores a JSON string; this app stores the same JSON as Data. Accept both.
    private static func jsonData(from stored: Any) -> Data? {
        if let raw = stored as? Data { return raw }
        if let text = stored as? String { return Data(text.utf8) }
        return nil
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(SavedState(habits: habits)) else { return }
        defaults.set(data, forKey: HabitStore.storageKey)
    }

    // MARK: - Today

    var todayKey: String { DayKey.key(for: now, calendar: calendar) }

    /// Moves "today" forward when the calendar day has changed (midnight, returning from background).
    func refreshDate(_ date: Date = Date()) {
        if DayKey.key(for: date, calendar: calendar) != todayKey {
            now = date
        }
    }

    func isDoneToday(_ habit: Habit) -> Bool {
        habit.isDone(on: todayKey)
    }

    var doneTodayCount: Int {
        let key = todayKey
        return habits.filter { $0.isDone(on: key) }.count
    }

    /// Share of habits done today, rounded like JavaScript's Math.round.
    var percent: Int {
        guard !habits.isEmpty else { return 0 }
        return Int((Double(doneTodayCount) / Double(habits.count) * 100).rounded())
    }

    var progressMessage: String {
        if habits.isEmpty { return "Add a habit to begin" }
        switch percent {
        case 100: return "All done. Beautifully done."
        case 75...: return "Almost there"
        case 1...: return "Nice, keep going"
        default: return "A gentle start"
        }
    }

    /// Days in a row with every habit done.
    var globalStreak: Int {
        guard !habits.isEmpty else { return 0 }
        let all = habits
        return DayKey.streak(endingAt: now, calendar: calendar) { key in
            all.allSatisfy { $0.isDone(on: key) }
        }
    }

    func streak(for habit: Habit) -> Int {
        DayKey.streak(endingAt: now, calendar: calendar) { habit.isDone(on: $0) }
    }

    func habits(in slot: TimeOfDay) -> [Habit] {
        habits.filter { $0.timeOfDay == slot }
    }

    /// The first card on screen (first habit of the first non-empty time slot).
    var firstHabitID: String? {
        for slot in TimeOfDay.allCases {
            if let habit = habits.first(where: { $0.timeOfDay == slot }) { return habit.id }
        }
        return nil
    }

    // MARK: - Changes

    func toggle(_ id: Habit.ID) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        let key = todayKey
        if habits[index].isDone(on: key) {
            habits[index].history[key] = nil
        } else {
            habits[index].history[key] = true
        }
        save()
    }

    func add(_ habit: Habit) {
        habits.append(habit)
        save()
    }

    /// Removes a habit and returns it with its old position, so it can be put back by Undo.
    @discardableResult
    func remove(_ id: Habit.ID) -> (habit: Habit, index: Int)? {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = habits.remove(at: index)
        if heatmapFilter == id { heatmapFilter = HabitStore.allFilter }
        save()
        return (removed, index)
    }

    func restore(_ habit: Habit, at index: Int) {
        guard !habits.contains(where: { $0.id == habit.id }) else { return }
        habits.insert(habit, at: min(max(index, 0), habits.count))
        save()
    }

    // MARK: - Heatmap

    var selectedHeatmapHabit: Habit? {
        guard heatmapFilter != HabitStore.allFilter else { return nil }
        return habits.first { $0.id == heatmapFilter }
    }

    func heatmap(days: Int = 90) -> Heatmap {
        let selected = selectedHeatmapHabit
        let list = selected.map { [$0] } ?? habits
        var cells: [Heatmap.Cell] = []
        cells.reserveCapacity(days + 1)
        var activeDays = 0
        for (index, daysAgo) in stride(from: days, through: 0, by: -1).enumerated() {
            let date = DayKey.adding(days: -daysAgo, to: now, calendar: calendar)
            let key = DayKey.key(for: date, calendar: calendar)
            let count = list.filter { $0.isDone(on: key) }.count
            let level = Heatmap.level(count: count, total: list.count)
            if level > 0 { activeDays += 1 }
            cells.append(Heatmap.Cell(id: index, date: date, count: count, level: level, isToday: daysAgo == 0))
        }
        return Heatmap(cells: cells, activeDays: activeDays, total: list.count, selectedHabit: selected)
    }
}
