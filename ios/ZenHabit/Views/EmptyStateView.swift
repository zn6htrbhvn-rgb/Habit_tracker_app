import SwiftUI

/// Shown when there are no habits: a few one-tap starters and a way to make your own.
struct EmptyStateView: View {
    let onStarter: (StarterHabit) -> Void
    let onCreate: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "leaf")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 72, height: 72)
                .background(Theme.accentSoft, in: Circle())
                .padding(.bottom, 16)
                .fadeUpIn(appeared, delay: 0, distance: 8, duration: 0.5)
                .accessibilityHidden(true)

            Text("A clean slate")
                .font(.display(.title2))
                .foregroundStyle(Theme.text)
                .padding(.bottom, 8)
                .fadeUpIn(appeared, delay: 0.06, distance: 8, duration: 0.5)
                .accessibilityAddTraits(.isHeader)

            Text("Nothing to track yet, and that's okay. The best habits start tiny. Pick one to begin:")
                .font(.body)
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 330)
                .padding(.bottom, 24)
                .fadeUpIn(appeared, delay: 0.12, distance: 8, duration: 0.5)

            FlowLayout(spacing: 8, lineSpacing: 8, centered: true) {
                ForEach(Array(Starters.all.enumerated()), id: \.element.id) { index, starter in
                    StarterChip(starter: starter) { onStarter(starter) }
                        .fadeUpIn(appeared, delay: 0.18 + Double(index) * 0.04, distance: 8, duration: 0.5)
                }
            }
            .padding(.bottom, 24)

            Button(action: onCreate) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Create your own")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .fadeUpIn(appeared, delay: 0.4, distance: 8, duration: 0.5)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Theme.borderStrong, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        }
        .onAppear { appeared = true }
    }
}

private struct StarterChip: View {
    let starter: StarterHabit
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: HabitIcon.symbol(for: starter.iconName))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(HabitTint(hex: starter.color).ink)
                Text(starter.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.text)
            }
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .frame(minHeight: 44)
            .background(Theme.surface, in: Capsule())
            .overlay { Capsule().strokeBorder(Theme.border, lineWidth: 1) }
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle(scale: 0.96))
        .hoverEffect(.highlight)
        .accessibilityLabel("Add \(starter.name)")
    }
}

/// One-time tip explaining tap, swipe and press-and-hold.
struct SwipeHint: View {
    let onDismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.draw")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.accent)
                .phaseAnimator([0.0, 6.0]) { content, nudge in
                    content.offset(x: reduceMotion ? 0 : nudge)
                } animation: { nudge in
                    nudge == 0 ? Motion.ease(0.45) : Motion.ease(0.45).delay(0.9)
                }
                .accessibilityHidden(true)
            Text("**Tip:** tap the circle to complete a habit, or swipe the card right →. Press and hold for more options.")
                .font(.subheadline)
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(PressableStyle(scale: 0.9))
            .accessibilityLabel("Dismiss tip")
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
