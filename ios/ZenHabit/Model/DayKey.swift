import Foundation

/// Calendar-day helpers. Days are identified by "yyyy-MM-dd" keys in local time, like the web app.
enum DayKey {
    static func key(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(pad(parts.year ?? 0, 4))-\(pad(parts.month ?? 0, 2))-\(pad(parts.day ?? 0, 2))"
    }

    /// Start of the day `days` away from `date` (negative goes back in time).
    static func adding(days: Int, to date: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: days, to: start) ?? start
    }

    /// Days in a row that pass `isDone`, ending today. A streak stays alive through today
    /// until the day is over: if today isn't done yet, count back from yesterday instead of showing 0.
    static func streak(endingAt today: Date, calendar: Calendar = .current, isDone: (String) -> Bool) -> Int {
        var day = calendar.startOfDay(for: today)
        if !isDone(key(for: day, calendar: calendar)) {
            day = adding(days: -1, to: day, calendar: calendar)
        }
        var count = 0
        while isDone(key(for: day, calendar: calendar)) {
            count += 1
            day = adding(days: -1, to: day, calendar: calendar)
        }
        return count
    }

    private static func pad(_ value: Int, _ width: Int) -> String {
        let digits = String(value)
        return digits.count >= width ? digits : String(repeating: "0", count: width - digits.count) + digits
    }
}
