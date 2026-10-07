import Foundation
import Testing
@testable import ZenHabit

struct HabitStoreTests {
    // Fixed calendar and clock so the tests don't depend on where or when they run.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func key(_ date: Date) -> String {
        DayKey.key(for: date, calendar: calendar)
    }

    private func emptyDefaults() -> UserDefaults {
        let name = "ZenHabitTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func makeStore(_ habits: [Habit], now: Date, defaults: UserDefaults? = nil) throws -> HabitStore {
        let defaults = defaults ?? emptyDefaults()
        let json = try JSONEncoder().encode(["habits": habits])
        defaults.set(json, forKey: HabitStore.storageKey)
        return HabitStore(defaults: defaults, calendar: calendar, now: now)
    }

    private func habit(_ id: String, slot: TimeOfDay = .morning, doneOn days: [Date] = []) -> Habit {
        var history: [String: Bool] = [:]
        for date in days { history[key(date)] = true }
        return Habit(id: id, name: "Habit \(id)", iconName: "leaf", color: "#3FA66B", timeOfDay: slot, history: history)
    }

    // MARK: - Storage

    @Test func firstLaunchStartsWithTheThreeSampleHabits() {
        let store = HabitStore(defaults: emptyDefaults(), calendar: calendar, now: day(2026, 3, 10))
        #expect(store.habits.map(\.name) == ["Morning Meditation", "Daily Reading", "Intense Workout"])
        #expect(store.habits.map(\.timeOfDay) == [.morning, .afternoon, .evening])
    }

    @Test func anEmptySavedListStaysEmpty() throws {
        let store = try makeStore([], now: day(2026, 3, 10))
        #expect(store.habits.isEmpty)
        #expect(store.progressMessage == "Add a habit to begin")
    }

    @Test func togglesAreSavedAndReloaded() throws {
        let defaults = emptyDefaults()
        let today = day(2026, 3, 10)
        let store = try makeStore([habit("a")], now: today, defaults: defaults)
        store.toggle("a")
        let reloaded = HabitStore(defaults: defaults, calendar: calendar, now: today)
        #expect(reloaded.habits[0].isDone(on: key(today)))

        reloaded.toggle("a")
        #expect(reloaded.habits[0].history.isEmpty)
    }

    @Test func readsTheWebAppsSavedStateAndUpgradesNeonColors() {
        let defaults = emptyDefaults()
        let webJSON = """
        {"habits":[{"id":"1","name":"Morning Meditation","iconName":"activity","color":"#00D1FF",\
        "timeOfDay":"morning","history":{"2026-03-09":true,"2026-03-10":true}}]}
        """
        defaults.set(webJSON, forKey: HabitStore.storageKey)
        let store = HabitStore(defaults: defaults, calendar: calendar, now: day(2026, 3, 10))
        #expect(store.habits.count == 1)
        #expect(store.habits[0].color == "#3A94D0")
        #expect(store.streak(for: store.habits[0]) == 2)
    }

    // MARK: - Progress

    @Test func percentRoundsLikeJavaScript() throws {
        let today = day(2026, 3, 10)
        let oneOfEight = try makeStore([habit("a", doneOn: [today])] + (1...7).map { habit("h\($0)") }, now: today)
        #expect(oneOfEight.percent == 13)

        let twoOfThree = try makeStore([habit("a", doneOn: [today]), habit("b", doneOn: [today]), habit("c")], now: today)
        #expect(twoOfThree.percent == 67)
        #expect(twoOfThree.doneTodayCount == 2)
        #expect(twoOfThree.progressMessage == "Nice, keep going")
    }

    @Test func progressMessagesFollowThePercentage() throws {
        let today = day(2026, 3, 10)
        let none = try makeStore([habit("a"), habit("b")], now: today)
        #expect(none.progressMessage == "A gentle start")

        let threeOfFour = try makeStore(
            [habit("a", doneOn: [today]), habit("b", doneOn: [today]), habit("c", doneOn: [today]), habit("d")],
            now: today
        )
        #expect(threeOfFour.progressMessage == "Almost there")

        let all = try makeStore([habit("a", doneOn: [today])], now: today)
        #expect(all.progressMessage == "All done. Beautifully done.")
    }

    // MARK: - Streaks

    @Test func aStreakSurvivesUntilTheDayIsOver() throws {
        let today = day(2026, 3, 10)
        let yesterday = day(2026, 3, 9)
        let twoDaysAgo = day(2026, 3, 8)
        let store = try makeStore([habit("a", doneOn: [yesterday, twoDaysAgo])], now: today)
        #expect(store.streak(for: store.habits[0]) == 2)

        store.toggle("a")
        #expect(store.streak(for: store.habits[0]) == 3)
    }

    @Test func aMissedDayBreaksTheStreak() throws {
        let today = day(2026, 3, 10)
        let store = try makeStore([habit("a", doneOn: [today, day(2026, 3, 8)])], now: today)
        #expect(store.streak(for: store.habits[0]) == 1)
    }

    @Test func theGlobalStreakNeedsEveryHabit() throws {
        let today = day(2026, 3, 10)
        let yesterday = day(2026, 3, 9)
        let store = try makeStore(
            [habit("a", doneOn: [today, yesterday]), habit("b", doneOn: [yesterday])],
            now: today
        )
        // Today isn't fully done yet, so the streak counts back from yesterday.
        #expect(store.globalStreak == 1)
        store.toggle("b")
        #expect(store.globalStreak == 2)
    }

    @Test func streaksCrossMonthBoundaries() throws {
        let store = try makeStore(
            [habit("a", doneOn: [day(2026, 2, 27), day(2026, 2, 28), day(2026, 3, 1)])],
            now: day(2026, 3, 1)
        )
        #expect(store.streak(for: store.habits[0]) == 3)
    }

    // MARK: - Delete and undo

    @Test func undoPutsADeletedHabitBackInPlace() throws {
        let store = try makeStore([habit("a"), habit("b"), habit("c")], now: day(2026, 3, 10))
        store.heatmapFilter = "b"
        let removed = try #require(store.remove("b"))
        #expect(removed.index == 1)
        #expect(store.habits.map(\.id) == ["a", "c"])
        #expect(store.heatmapFilter == HabitStore.allFilter)

        store.restore(removed.habit, at: removed.index)
        #expect(store.habits.map(\.id) == ["a", "b", "c"])

        // Restoring twice doesn't duplicate it.
        store.restore(removed.habit, at: removed.index)
        #expect(store.habits.count == 3)
    }

    // MARK: - Heatmap

    @Test func heatmapLevelsMatchTheWebThresholds() {
        #expect(Heatmap.level(count: 0, total: 4) == 0)
        #expect(Heatmap.level(count: 1, total: 4) == 1)
        #expect(Heatmap.level(count: 2, total: 4) == 2)
        #expect(Heatmap.level(count: 3, total: 4) == 3)
        #expect(Heatmap.level(count: 4, total: 4) == 4)
        #expect(Heatmap.level(count: 1, total: 0) == 0)
    }

    @Test func heatmapCoversTheLast90DaysPlusToday() throws {
        let today = day(2026, 3, 10)
        let store = try makeStore(
            [habit("a", doneOn: [today, day(2026, 3, 9)]), habit("b", doneOn: [today])],
            now: today
        )
        let all = store.heatmap()
        #expect(all.cells.count == 91)
        #expect(all.cells.last?.isToday == true)
        #expect(all.cells.last?.level == 4)
        #expect(all.cells[all.cells.count - 2].level == 2)
        #expect(all.activeDays == 2)
        #expect(key(all.cells[0].date) == key(day(2025, 12, 10)))

        store.heatmapFilter = "b"
        let onlyB = store.heatmap()
        #expect(onlyB.selectedHabit?.id == "b")
        #expect(onlyB.total == 1)
        #expect(onlyB.activeDays == 1)
    }

    @Test func dayKeysAreZeroPadded() {
        #expect(key(day(2026, 3, 5)) == "2026-03-05")
    }
}
