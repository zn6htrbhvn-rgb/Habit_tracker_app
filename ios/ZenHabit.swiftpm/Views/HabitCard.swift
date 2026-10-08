import SwiftUI

/// One habit row. Tap the circle to complete it, swipe right to complete/undo,
/// press and hold (or right-click) for more, or use the "…" button.
struct HabitCard: View {
    let habit: Habit
    let isDone: Bool
    let streak: Int
    /// Plays the "just added" wash when the card first appears.
    var justAdded = false
    /// Nudges the card right once to show that it can be swiped.
    var peek = false
    let onToggle: () -> Void
    let onMore: () -> Void
    let onDelete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.45, dampingFraction: 0.68)))
    private var swipe = SwipeState()
    @State private var peekOffset: CGFloat = 0
    @State private var doneBursts = 0
    @State private var undoneDips = 0
    @State private var addedBursts = 0

    private static let threshold: CGFloat = 80
    private static let peekDistance: CGFloat = 56

    private var tint: HabitTint { HabitTint(hex: habit.color) }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 20, style: .continuous) }
    private var armed: Bool { swipe.dx > Self.threshold }
    private var revealProgress: CGFloat {
        min(max(swipe.dx / Self.threshold, peekOffset / Self.peekDistance), 1)
    }

    var body: some View {
        cardBody
            .offset(x: rubberBand(swipe.dx) + peekOffset)
            .background { swipeBackground }
            .simultaneousGesture(swipeGesture)
            .sensoryFeedback(.impact(weight: .light), trigger: armed) { _, isArmed in isArmed }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: isDone) { _, done in done }
            .onChange(of: isDone) { _, done in
                if done { doneBursts += 1 } else { undoneDips += 1 }
            }
            .onAppear {
                if justAdded && !reduceMotion { addedBursts += 1 }
            }
            .task(id: peek) { await runPeek() }
    }

    // MARK: - Card

    private var cardBody: some View {
        HStack(spacing: 12) {
            iconTile
            info
            moreButton
            checkButton
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 12)
        .frame(minHeight: 76)
        .background {
            ZStack {
                shape
                    .fill(isDone ? tint.tint : Theme.surface)
                    .zenShadow(swipe.phase == .swiping ? .large : .small)
                WashLayer(color: tint.color, doneTrigger: doneBursts, addedTrigger: addedBursts)
                    .clipShape(shape)
            }
        }
        .overlay {
            shape.strokeBorder(isDone ? tint.doneBorder : Theme.border, lineWidth: 1)
        }
        .contentShape(.contextMenuPreview, shape)
        .contentShape(shape)
        .contextMenu { contextMenuItems }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: isDone ? "Mark not done today" : "Mark done today", onToggle)
        .accessibilityAction(named: "Delete habit", onDelete)
    }

    private var iconTile: some View {
        IconTile(icon: habit.iconName, tint: tint, filled: isDone)
            .keyframeAnimator(initialValue: TileMotion(), trigger: doneBursts) { content, value in
                content.scaleEffect(value.scale).rotationEffect(.degrees(value.angle))
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    CubicKeyframe(1.12, duration: 0.21)
                    SpringKeyframe(1, duration: 0.31)
                }
                KeyframeTrack(\.angle) {
                    CubicKeyframe(-4, duration: 0.21)
                    SpringKeyframe(0, duration: 0.31)
                }
            }
            .keyframeAnimator(initialValue: TileMotion(), trigger: addedBursts) { content, value in
                content.scaleEffect(value.scale).rotationEffect(.degrees(value.angle))
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    MoveKeyframe(0.6)
                    LinearKeyframe(0.6, duration: 0.4)
                    SpringKeyframe(1, duration: 0.56, spring: .bouncy)
                }
                KeyframeTrack(\.angle) {
                    MoveKeyframe(-10)
                    LinearKeyframe(-10, duration: 0.4)
                    SpringKeyframe(0, duration: 0.56, spring: .bouncy)
                }
            }
            .animation(Motion.ease(0.25), value: isDone)
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(habit.name)
                .font(.headline)
                .foregroundStyle(Theme.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            HStack(spacing: 6) {
                Image(systemName: "flame")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(streak > 0 ? tint.ink : Theme.textMuted)
                Text(streak > 0 ? "\(streak)-day streak" : "Start a streak today")
                    .font(.footnote.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textMuted)
                    .contentTransition(.numericText(value: Double(streak)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var moreButton: some View {
        Button(action: onMore) {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle(scale: 0.9))
        .hoverEffect(.highlight)
        .accessibilityLabel("More options for \(habit.name)")
    }

    private var checkButton: some View {
        Button(action: onToggle) {
            ZStack {
                Circle()
                    .fill(isDone ? tint.fill : Theme.surface)
                Circle()
                    .strokeBorder(isDone ? tint.fill : tint.checkBorder, lineWidth: 2.5)
                Image(systemName: "checkmark")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(HabitTint.onHabit)
                    .opacity(isDone ? 1 : 0)
                    .keyframeAnimator(initialValue: TileMotion(), trigger: doneBursts) { content, value in
                        content.scaleEffect(value.scale).rotationEffect(.degrees(value.angle))
                    } keyframes: { _ in
                        KeyframeTrack(\.scale) {
                            MoveKeyframe(0)
                            LinearKeyframe(1, duration: 0.42, timingCurve: .easeOut)
                        }
                        KeyframeTrack(\.angle) {
                            MoveKeyframe(-30)
                            LinearKeyframe(0, duration: 0.42, timingCurve: .easeOut)
                        }
                    }
            }
            .frame(width: 48, height: 48)
            .keyframeAnimator(initialValue: 1.0, trigger: doneBursts) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack {
                    MoveKeyframe(0.7)
                    CubicKeyframe(1.15, duration: 0.31)
                    SpringKeyframe(1, duration: 0.21)
                }
            }
            .keyframeAnimator(initialValue: 1.0, trigger: undoneDips) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(0.86, duration: 0.14)
                    CubicKeyframe(1, duration: 0.22)
                }
            }
            .overlay { RingBurst(color: tint.color, trigger: doneBursts) }
            .animation(Motion.ease(0.25), value: isDone)
            .contentShape(Circle())
        }
        .buttonStyle(PressableStyle(scale: 0.9))
        .hoverEffect(.lift)
        .accessibilityLabel(isDone ? "Completed: \(habit.name)" : "Complete: \(habit.name)")
        .accessibilityAddTraits(isDone ? .isSelected : [])
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        // Give the menu a moment to close so the card's reaction is visible.
        Button {
            runAfter(0.35, onToggle)
        } label: {
            Label(isDone ? "Mark not done today" : "Mark done today",
                  systemImage: isDone ? "arrow.uturn.backward.circle" : "checkmark.circle")
        }
        Button(role: .destructive) {
            runAfter(0.35, onDelete)
        } label: {
            Label("Delete habit", systemImage: "trash")
        }
    }

    // MARK: - Swipe

    private var swipeBackground: some View {
        HStack(spacing: 8) {
            Image(systemName: isDone ? "arrow.uturn.backward" : "checkmark.circle")
                .font(.system(size: 24, weight: .semibold))
                .scaleEffect(armed ? 1.25 : 0.6 + 0.4 * revealProgress)
                .rotationEffect(.degrees(armed ? 0 : Double(1 - revealProgress) * -40))
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: armed)
            Text(isDone ? "Undo" : "Done")
                .font(.subheadline.weight(.bold))
        }
        .foregroundStyle(HabitTint.onHabit)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(tint.fill, in: shape)
        .opacity(revealProgress)
        .accessibilityHidden(true)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($swipe) { value, state, _ in
                let move = value.translation
                // Only a mostly-horizontal rightward drag becomes a swipe; anything else is a scroll.
                if state.phase == .idle {
                    state.phase = move.width > 0 && abs(move.width) > abs(move.height) * 1.2 ? .swiping : .rejected
                }
                if state.phase == .swiping {
                    state.dx = max(0, move.width)
                }
            }
            .onEnded { value in
                let move = value.translation
                guard move.width > Self.threshold, abs(move.width) > abs(move.height) * 1.2 else { return }
                runAfter(reduceMotion ? 0 : 0.16, onToggle)
            }
    }

    /// Past the threshold the card drags with resistance, so it feels physical.
    private func rubberBand(_ dx: CGFloat) -> CGFloat {
        dx > Self.threshold ? Self.threshold + (dx - Self.threshold) * 0.35 : dx
    }

    private func runPeek() async {
        guard peek, !reduceMotion else { return }
        try? await Task.sleep(for: .milliseconds(600))
        guard !Task.isCancelled else { return }
        withAnimation(Motion.ease(0.5)) { peekOffset = Self.peekDistance }
        try? await Task.sleep(for: .milliseconds(780))
        withAnimation(Motion.ease(0.6)) { peekOffset = 0 }
    }
}

private struct SwipeState: Equatable {
    enum Phase { case idle, swiping, rejected }
    var phase: Phase = .idle
    var dx: CGFloat = 0
}

private struct TileMotion {
    var scale: Double = 1
    var angle: Double = 0
}

private struct BurstMotion {
    var scale: Double = 0
    var opacity: Double = 0
}

/// A ring that bursts outward from the check circle.
private struct RingBurst: View {
    let color: Color
    let trigger: Int

    var body: some View {
        Circle()
            .strokeBorder(color, lineWidth: 3)
            .padding(-3)
            .keyframeAnimator(initialValue: BurstMotion(scale: 1, opacity: 0), trigger: trigger) { content, value in
                content.scaleEffect(value.scale).opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    MoveKeyframe(1)
                    LinearKeyframe(1.8, duration: 0.62, timingCurve: .easeOut)
                }
                KeyframeTrack(\.opacity) {
                    MoveKeyframe(0.7)
                    LinearKeyframe(0, duration: 0.62, timingCurve: .easeOut)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Color washing across the card from the check circle when it's completed (or just added).
private struct WashLayer: View {
    let color: Color
    let doneTrigger: Int
    let addedTrigger: Int

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let diameter = 2 * hypot(size.width, size.height)
            let center = CGPoint(x: size.width - 32, y: size.height / 2)
            ZStack {
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: diameter, height: diameter)
                    .keyframeAnimator(initialValue: BurstMotion(), trigger: doneTrigger) { content, value in
                        content.scaleEffect(value.scale).opacity(value.opacity)
                    } keyframes: { _ in
                        KeyframeTrack(\.scale) {
                            MoveKeyframe(0)
                            LinearKeyframe(1, duration: 0.9, timingCurve: .easeOut)
                        }
                        KeyframeTrack(\.opacity) {
                            MoveKeyframe(1)
                            LinearKeyframe(0, duration: 0.9, timingCurve: .easeOut)
                        }
                    }
                    .position(center)
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: diameter, height: diameter)
                    .keyframeAnimator(initialValue: BurstMotion(), trigger: addedTrigger) { content, value in
                        content.scaleEffect(value.scale).opacity(value.opacity)
                    } keyframes: { _ in
                        KeyframeTrack(\.scale) {
                            MoveKeyframe(0)
                            LinearKeyframe(0, duration: 0.35)
                            LinearKeyframe(1, duration: 1.1, timingCurve: .easeOut)
                        }
                        KeyframeTrack(\.opacity) {
                            MoveKeyframe(1)
                            LinearKeyframe(1, duration: 0.35)
                            LinearKeyframe(0, duration: 1.1, timingCurve: .easeOut)
                        }
                    }
                    .position(center)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Header above each time-of-day group: icon, name, "done/total" and a hairline.
struct SectionHeader: View {
    let slot: TimeOfDay
    let done: Int
    let total: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: slot.symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textMuted)
                .frame(width: 32, height: 32)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(slot.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.text)
            Text("\(done)/\(total)")
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.textMuted)
                .contentTransition(.numericText(value: Double(done)))
                .keyframeAnimator(initialValue: 1.0, trigger: "\(done)/\(total)") { content, scale in
                    content.scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(1.3, duration: 0.19)
                        SpringKeyframe(1, duration: 0.29)
                    }
                }
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(slot.title), \(done) of \(total) done")
        .accessibilityAddTraits(.isHeader)
    }
}
