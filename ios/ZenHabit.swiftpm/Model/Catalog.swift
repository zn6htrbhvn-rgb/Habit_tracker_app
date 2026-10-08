import Foundation

struct HabitColor: Identifiable, Hashable {
    let hex: String
    let name: String
    var id: String { hex }
}

/// Calm-but-vivid accents that hold up on both light and dark backgrounds.
enum HabitPalette {
    static let colors: [HabitColor] = [
        HabitColor(hex: "#E0643C", name: "Terracotta"),
        HabitColor(hex: "#3A94D0", name: "Sky"),
        HabitColor(hex: "#8A6FE0", name: "Lavender"),
        HabitColor(hex: "#3FA66B", name: "Sage"),
        HabitColor(hex: "#E0A030", name: "Ochre"),
        HabitColor(hex: "#E0507F", name: "Rose"),
        HabitColor(hex: "#22A39A", name: "Teal"),
        HabitColor(hex: "#6B7A8F", name: "Slate"),
    ]

    /// Old neon palette → current palette, so habits saved by early versions keep "their" color.
    static let legacy: [String: String] = [
        "#FF603E": "#E0643C", "#00D1FF": "#3A94D0", "#7C5CFF": "#8A6FE0",
        "#00FF85": "#3FA66B", "#FFD600": "#E0A030", "#FF00BD": "#E0507F",
    ]
}

/// Icon ids are the web app's Lucide names (so saved data is shared); each maps to the closest SF Symbol.
enum HabitIcon {
    static let all: [String] = [
        "activity", "coffee", "droplets", "utensils", "book-open", "bed", "dumbbell",
        "bike", "waves", "trees", "leaf", "heart", "smile", "music", "camera", "brush",
        "code", "monitor", "briefcase", "graduation-cap", "pill",
    ]

    private static let symbols: [String: String] = [
        "activity": "waveform.path.ecg",
        "coffee": "cup.and.saucer",
        "droplets": "drop",
        "utensils": "fork.knife",
        "book-open": "book",
        "bed": "bed.double",
        "dumbbell": "dumbbell",
        "bike": "bicycle",
        "waves": "water.waves",
        "trees": "tree",
        "leaf": "leaf",
        "heart": "heart",
        "smile": "face.smiling",
        "music": "music.note",
        "camera": "camera",
        "brush": "paintbrush",
        "code": "chevron.left.forwardslash.chevron.right",
        "monitor": "display",
        "briefcase": "briefcase",
        "graduation-cap": "graduationcap",
        "pill": "pill",
    ]

    static func symbol(for name: String) -> String {
        symbols[name] ?? "circle"
    }

    /// Spoken name for VoiceOver, e.g. "book open".
    static func label(for name: String) -> String {
        name.replacingOccurrences(of: "-", with: " ")
    }
}

struct StarterHabit: Identifiable {
    let name: String
    let iconName: String
    let color: String
    let timeOfDay: TimeOfDay
    var id: String { name }
}

enum Starters {
    /// One-tap suggestions shown in the empty state.
    static let all: [StarterHabit] = [
        StarterHabit(name: "Drink a glass of water", iconName: "droplets", color: "#3A94D0", timeOfDay: .morning),
        StarterHabit(name: "Stretch for 5 minutes", iconName: "activity", color: "#3FA66B", timeOfDay: .morning),
        StarterHabit(name: "Take a short walk", iconName: "trees", color: "#22A39A", timeOfDay: .afternoon),
        StarterHabit(name: "Read 10 pages", iconName: "book-open", color: "#8A6FE0", timeOfDay: .evening),
        StarterHabit(name: "Screens off by 10pm", iconName: "bed", color: "#6B7A8F", timeOfDay: .evening),
    ]
}

extension Habit {
    /// What a brand-new install starts with (same as the web app).
    static let seeds: [Habit] = [
        Habit(id: "1", name: "Morning Meditation", iconName: "activity", color: HabitPalette.colors[1].hex, timeOfDay: .morning),
        Habit(id: "2", name: "Daily Reading", iconName: "book-open", color: HabitPalette.colors[2].hex, timeOfDay: .afternoon),
        Habit(id: "3", name: "Intense Workout", iconName: "dumbbell", color: HabitPalette.colors[0].hex, timeOfDay: .evening),
    ]
}
