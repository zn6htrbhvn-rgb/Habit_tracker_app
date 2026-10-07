import Foundation

/// The three parts of the day that habits are grouped into.
enum TimeOfDay: String, Codable, CaseIterable, Identifiable {
    case morning, afternoon, evening

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .morning: return "sun.max"
        case .afternoon: return "cloud"
        case .evening: return "moon"
        }
    }
}

/// One habit. Field names and JSON shape match the web app's saved state
/// (`{ "habits": [...] }` in localStorage), so data stays portable between the two.
struct Habit: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    /// The web app's Lucide icon name, e.g. "book-open". See `HabitIcon` for the SF Symbol it maps to.
    var iconName: String
    /// Hex accent color, e.g. "#3A94D0".
    var color: String
    var timeOfDay: TimeOfDay
    /// Completed days keyed "yyyy-MM-dd" (local time). Only `true` entries are stored.
    var history: [String: Bool]

    init(
        id: String = UUID().uuidString,
        name: String,
        iconName: String,
        color: String,
        timeOfDay: TimeOfDay,
        history: [String: Bool] = [:]
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.color = color
        self.timeOfDay = timeOfDay
        self.history = history
    }

    func isDone(on dayKey: String) -> Bool {
        history[dayKey] == true
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, iconName, color, timeOfDay, history
    }

    // Lenient decoding: older saves may have numeric ids, neon legacy colors or missing fields.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringID = try? container.decode(String.self, forKey: .id) {
            id = stringID
        } else {
            id = String(try container.decode(Int.self, forKey: .id))
        }
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName) ?? HabitIcon.all[0]
        let storedColor = try container.decodeIfPresent(String.self, forKey: .color) ?? HabitPalette.colors[0].hex
        color = HabitPalette.legacy[storedColor.uppercased()] ?? storedColor
        let slot = try container.decodeIfPresent(String.self, forKey: .timeOfDay) ?? ""
        timeOfDay = TimeOfDay(rawValue: slot) ?? .morning
        history = try container.decodeIfPresent([String: Bool].self, forKey: .history) ?? [:]
    }
}
