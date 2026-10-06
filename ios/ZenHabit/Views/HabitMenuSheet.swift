import SwiftUI

/// Options for one habit, opened from its "…" button.
struct HabitMenuSheet: View {
    let habit: Habit
    let isDone: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var contentHeight: CGFloat = 320
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 12) {
                IconTile(icon: habit.iconName, tint: HabitTint(hex: habit.color))
                Text(habit.name)
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
            }

            VStack(spacing: 8) {
                MenuRow(
                    title: isDone ? "Mark not done today" : "Mark done today",
                    symbol: isDone ? "arrow.uturn.backward.circle" : "checkmark.circle",
                    destructive: false
                ) {
                    dismiss()
                    onToggle()
                }
                .fadeUpIn(appeared, delay: 0.12, distance: 16, duration: 0.48)

                MenuRow(title: "Delete habit", symbol: "trash", destructive: true) {
                    dismiss()
                    onDelete()
                }
                .fadeUpIn(appeared, delay: 0.165, distance: 16, duration: 0.48)

                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle(scale: 0.98))
                .keyboardShortcut(.cancelAction)
                .fadeUpIn(appeared, delay: 0.21, distance: 16, duration: 0.48)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            contentHeight = height
        }
        .presentationDetents([.height(contentHeight)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(Theme.surface)
        .fittedFormSheet()
        .onAppear { appeared = true }
    }
}

private struct MenuRow: View {
    let title: String
    let symbol: String
    let destructive: Bool
    let action: () -> Void

    var body: some View {
        let tile = RoundedRectangle(cornerRadius: 14, style: .continuous)
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .medium))
                Text(title)
                    .font(.body.weight(.semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(destructive ? Theme.danger : Theme.text)
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(destructive ? Theme.dangerSoft : Theme.surface2, in: tile)
            .contentShape(tile)
        }
        .buttonStyle(PressableStyle(scale: 0.98))
        .hoverEffect(.highlight)
    }
}
