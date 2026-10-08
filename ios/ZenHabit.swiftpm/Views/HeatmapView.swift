import SwiftUI

/// "Velocity Visualizer": the last 90 days as a 13-column heatmap, filterable by habit.
struct HeatmapView: View {
    let heatmap: Heatmap
    let habits: [Habit]
    /// "all" or a habit id; used to ripple colors when the filter changes.
    let filter: String
    let introVisible: Bool
    let introDelay: Double
    let onSelectFilter: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var inspectedCell: Int?

    private static let columns = 13
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 5), count: Self.columns)
    }
    private var cellsShown: Bool { introVisible || reduceMotion }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 28, style: .continuous) }

    /// The color the cells build up to: the selected habit's color, or sage for all habits.
    private var heatUI: UIColor {
        heatmap.selectedHabit.map { UIColor(hex: $0.color) } ?? Theme.accentUI
    }

    private var who: String {
        heatmap.selectedHabit?.name ?? "all habits"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 16)
            if habits.count >= 2 {
                filterChips
                    .padding(.bottom, 16)
            }
            grid
                .padding(.bottom, 12)
            footer
        }
        .padding(24)
        .background {
            shape
                .fill(Theme.surface)
                .zenShadow(.small)
        }
        .overlay {
            shape.strokeBorder(Theme.border, lineWidth: 1)
        }
        .task(id: inspectedCell) {
            guard inspectedCell != nil else { return }
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation(Motion.ease(0.2)) { inspectedCell = nil }
        }
    }

    // MARK: - Header

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                titleBlock
                Spacer(minLength: 0)
                legend
                    .padding(.top, 8)
            }
            VStack(alignment: .leading, spacing: 16) {
                titleBlock
                legend
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Velocity Visualizer")
                .font(.display(.title2))
                .foregroundStyle(Theme.text)
                .accessibilityAddTraits(.isHeader)
            Text("\(heatmap.activeDays) active \(heatmap.activeDays == 1 ? "day" : "days") · \(who)")
                .font(.subheadline)
                .foregroundStyle(Theme.textMuted)
                .contentTransition(.opacity)
        }
    }

    private var legend: some View {
        HStack(spacing: 3) {
            Text("Less")
                .padding(.trailing, 4)
            ForEach(0..<5) { level in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color(forLevel: level))
                    .frame(width: 12, height: 12)
            }
            Text("More")
                .padding(.leading, 4)
        }
        .font(.footnote)
        .foregroundStyle(Theme.textMuted)
        .animation(Motion.ease(0.45), value: filter)
        .accessibilityHidden(true)
    }

    // MARK: - Filter

    private var filterChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                FilterChip(title: "All habits", tint: HabitTint(base: Theme.accentUI), active: heatmap.selectedHabit == nil) {
                    onSelectFilter(HabitStore.allFilter)
                }
                ForEach(habits) { habit in
                    FilterChip(title: habit.name, tint: HabitTint(hex: habit.color), active: heatmap.selectedHabit?.id == habit.id) {
                        onSelectFilter(habit.id)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        // Let the chips scroll edge to edge of the card.
        .padding(.horizontal, -24)
    }

    // MARK: - Grid

    private var grid: some View {
        LazyVGrid(columns: gridColumns, spacing: 5) {
            ForEach(heatmap.cells) { cell in
                cellView(cell)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Completion heatmap for the last 90 days")
        .accessibilityValue("\(heatmap.activeDays) active days for \(who)")
    }

    private func cellView(_ cell: Heatmap.Cell) -> some View {
        // Changes ripple through the grid diagonally, from the top-left corner.
        let wave = Double(cell.id % Self.columns + cell.id / Self.columns)
        let inspected = inspectedCell == cell.id
        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(color(forLevel: cell.level))
            .animation(reduceMotion ? nil : Motion.ease(0.45).delay(wave * 0.018), value: "\(cell.level)|\(filter)")
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if cell.isToday { todayRing }
            }
            .scaleEffect(inspected ? 1.2 : 1)
            .zIndex(inspected ? 1 : 0)
            .animation(Motion.ease(0.15), value: inspected)
            .scaleEffect(cellsShown ? 1 : 0.3)
            .opacity(cellsShown ? 1 : 0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.56, dampingFraction: 0.6).delay(introDelay + wave * 0.02),
                value: cellsShown
            )
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(Motion.ease(0.2)) {
                    inspectedCell = inspected ? nil : cell.id
                }
            }
            .help(tip(for: cell))
    }

    /// Today's cell gets a ring: a gap in the card color, then a thin line in the text color.
    private var todayRing: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Theme.text, lineWidth: 1.5)
                .padding(-3.5)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Theme.surface, lineWidth: 2)
                .padding(-2)
        }
        .allowsHitTesting(false)
    }

    private var footer: some View {
        ZStack {
            if let inspectedCell, let cell = heatmap.cells.first(where: { $0.id == inspectedCell }) {
                Text(tip(for: cell))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            } else {
                HStack {
                    Text("90 days ago")
                    Spacer()
                    Text("Today")
                }
                .transition(.opacity)
            }
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(Theme.textMuted)
    }

    // MARK: - Helpers

    private func color(forLevel level: Int) -> Color {
        switch level {
        case 0: return Theme.heatmapEmpty
        case 1: return Color(uiColor: .zenMix(heatUI, Theme.heatmapEmptyUI, 0.30))
        case 2: return Color(uiColor: .zenMix(heatUI, Theme.heatmapEmptyUI, 0.55))
        case 3: return Color(uiColor: .zenMix(heatUI, Theme.heatmapEmptyUI, 0.78))
        default: return Color(uiColor: heatUI)
        }
    }

    private func tip(for cell: Heatmap.Cell) -> String {
        let day = cell.date.formatted(.dateTime.month(.abbreviated).day())
        if heatmap.selectedHabit != nil {
            return "\(day): \(cell.count > 0 ? "done" : "not done")"
        }
        return "\(day): \(cell.count) of \(heatmap.total) habits"
    }
}

private struct FilterChip: View {
    let title: String
    let tint: HabitTint
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(tint.color)
                    .frame(width: 10, height: 10)
                    .scaleEffect(active ? 1.3 : 1)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(active ? Theme.text : Theme.textMuted)
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .frame(minHeight: 40)
            .background(active ? tint.tint : Theme.surface, in: Capsule())
            .overlay {
                Capsule().strokeBorder(active ? tint.ink : Theme.border, lineWidth: 1.5)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle(scale: 0.95))
        .animation(Motion.spring(0.45), value: active)
        .accessibilityLabel("Show \(title)")
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}
