import SwiftUI

// MARK: - Buttons

/// Shrinks a little while pressed, like the web app's `:active` states.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Sage pill button ("New habit", "Add habit").
struct PrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 44
    var expands = false
    var font: Font = .subheadline.weight(.semibold)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, 24)
            .frame(maxWidth: expands ? .infinity : nil, minHeight: height)
            .background {
                Capsule()
                    .fill(configuration.isPressed ? Theme.accentHover : Theme.accent)
                    .zenShadow(.small)
            }
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Quiet stone pill button ("Cancel").
struct SecondaryButtonStyle: ButtonStyle {
    var height: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 24)
            .frame(minHeight: height)
            .background(configuration.isPressed ? Theme.surface3 : Theme.surface2, in: Capsule())
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Habit icon tile

/// The rounded square with a habit's icon: tinted normally, solid once the habit is done.
struct IconTile: View {
    let icon: String
    let tint: HabitTint
    var filled = false
    var size: CGFloat = 48

    var body: some View {
        Image(systemName: HabitIcon.symbol(for: icon))
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(filled ? HabitTint.onHabit : tint.ink)
            .frame(width: size, height: size)
            .background(filled ? tint.fill : tint.tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityHidden(true)
    }
}

// MARK: - Flow layout

/// Lays children out left to right and wraps onto new lines (CSS `flex-wrap`).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8
    var centered = false

    private struct Item {
        let index: Int
        let size: CGSize
    }

    private struct Row {
        var items: [Item] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = makeRows(maxWidth: maxWidth, subviews: subviews)
        let contentWidth = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(rows.count - 1, 0))
        let width = maxWidth.isFinite ? maxWidth : contentWidth
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in makeRows(maxWidth: bounds.width, subviews: subviews) {
            var x = bounds.minX + (centered ? max(0, (bounds.width - row.width) / 2) : 0)
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y + (row.height - item.size.height) / 2),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private func makeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            var size = subviews[index].sizeThatFits(.unspecified)
            if size.width > maxWidth {
                size = subviews[index].sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            }
            if !current.items.isEmpty && current.width + spacing + size.width > maxWidth {
                rows.append(current)
                current = Row()
            }
            current.width += (current.items.isEmpty ? 0 : spacing) + size.width
            current.height = max(current.height, size.height)
            current.items.append(Item(index: index, size: size))
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}

// MARK: - Motion helpers

/// Fades and rises a view into place once `visible` turns true (used for staggered entrances).
private struct FadeUpIn: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let visible: Bool
    let delay: Double
    let distance: CGFloat
    let duration: Double

    private var shown: Bool { visible || reduceMotion }

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : distance)
            .animation(reduceMotion ? nil : Motion.ease(duration).delay(delay), value: shown)
    }
}

extension View {
    func fadeUpIn(_ visible: Bool, delay: Double, distance: CGFloat = 10, duration: Double = 0.67) -> some View {
        modifier(FadeUpIn(visible: visible, delay: delay, distance: distance, duration: duration))
    }

    /// Sizes iPad sheets to their content where the system supports it (iOS 18+).
    @ViewBuilder
    func fittedFormSheet() -> some View {
        if #available(iOS 18.0, *) {
            self.presentationSizing(.form.fitted(horizontal: false, vertical: true))
        } else {
            self
        }
    }
}

/// Side-to-side wiggle for invalid input. Animate `shakes` up by 1 to play it once.
struct ShakeEffect: GeometryEffect {
    var travel: CGFloat = 5
    var animatableData: CGFloat

    init(shakes: Int) {
        animatableData = CGFloat(shakes)
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * sin(animatableData * .pi * 4), y: 0))
    }
}

/// Runs `work` on the main actor after a short pause (0 runs it on the next turn of the run loop).
@MainActor
func runAfter(_ seconds: Double, _ work: @escaping @MainActor () -> Void) {
    Task { @MainActor in
        if seconds > 0 {
            try? await Task.sleep(for: .seconds(seconds))
        }
        work()
    }
}

/// Remembers on-screen frames without re-rendering anything when they change (they change on every scroll).
final class FrameBox {
    var themeButton: CGRect = .zero
    var progressCard: CGRect = .zero
}
