import SwiftUI

/// "Today's progress": the big counting percentage, the bar, and a gentle nudge.
struct ProgressCard: View {
    let percent: Int
    let done: Int
    let total: Int
    let message: String
    /// Bumped each time the last habit of the day gets done.
    let celebrations: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var percentSize: CGFloat = 40
    @State private var shownPercent: Double = 0
    @State private var barFraction: Double = 0

    private var complete: Bool { percent == 100 }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 28, style: .continuous) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                Text("Today's progress")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textMuted)
                Spacer(minLength: 8)
                CountingPercent(value: shownPercent)
                    .font(.system(size: percentSize, weight: .semibold, design: .serif))
                    .monospacedDigit()
                    .tracking(-0.8)
                    .foregroundStyle(Theme.text)
            }
            .padding(.bottom, 16)

            ProgressTrack(fraction: barFraction, complete: complete)
                .frame(height: 12)
                .padding(.bottom, 12)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(done) of \(total) completed")
                    .lineLimit(1)
                    .foregroundStyle(Theme.textMuted)
                Spacer(minLength: 0)
                ZStack(alignment: .trailing) {
                    Text(message)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.text)
                        .multilineTextAlignment(.trailing)
                        .id(message)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 6)), removal: .opacity))
                }
            }
            .font(.subheadline.weight(.medium))
        }
        .padding(24)
        .background {
            ZStack {
                // 4pt sage halo once everything is done.
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Theme.accentSoft)
                    .padding(-4)
                    .opacity(complete ? 1 : 0)
                shape
                    .fill(Theme.surface)
                    .zenShadow(.medium)
            }
        }
        .overlay {
            shape.strokeBorder(complete ? Theme.completeBorder : Theme.border, lineWidth: 1)
        }
        .animation(Motion.ease(0.45), value: complete)
        .keyframeAnimator(initialValue: 1.0, trigger: celebrations) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(1.025, duration: 0.25)
                SpringKeyframe(1.0, duration: 0.45)
            }
        }
        .onAppear { playIntro() }
        .onChange(of: percent) { _, newValue in
            move(to: newValue, numberDuration: 0.9, delay: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's progress")
        .accessibilityValue("\(percent) percent. \(done) of \(total) completed. \(message)")
    }

    /// On launch the bar fills and the number counts up from zero.
    private func playIntro() {
        guard !reduceMotion else {
            shownPercent = Double(percent)
            barFraction = Double(percent) / 100
            return
        }
        move(to: percent, numberDuration: 1.1, delay: 0.43)
    }

    private func move(to value: Int, numberDuration: Double, delay: Double) {
        if reduceMotion {
            shownPercent = Double(value)
            barFraction = Double(value) / 100
            return
        }
        // Ease-out cubic for the number, a springy overshoot for the bar.
        withAnimation(.timingCurve(0.33, 1, 0.68, 1, duration: numberDuration).delay(delay)) {
            shownPercent = Double(value)
        }
        withAnimation(.spring(response: 0.8, dampingFraction: 0.62).delay(delay)) {
            barFraction = Double(value) / 100
        }
    }
}

/// A percentage that counts through every number on its way to a new value.
private struct CountingPercent: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(Int(value.rounded()))%")
    }
}

struct ProgressTrack: View {
    let fraction: Double
    let complete: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surface2)
                fill
                    .frame(width: max(0, proxy.size.width * fraction))
                    .clipShape(Capsule())
            }
        }
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var fill: some View {
        if complete && !reduceMotion {
            // A warm highlight sweeps through the bar while every habit is done.
            TimelineView(.animation) { context in
                let cycle = 2.4
                let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle) / cycle
                let shift = 2 * phase
                LinearGradient(
                    colors: [Theme.accent, Theme.shimmer, Theme.accent, Theme.shimmer, Theme.accent],
                    startPoint: UnitPoint(x: shift - 2, y: 0.5),
                    endPoint: UnitPoint(x: shift + 2, y: 0.5)
                )
            }
        } else {
            Theme.accent
        }
    }
}
