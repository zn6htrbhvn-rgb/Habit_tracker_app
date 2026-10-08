import SwiftUI

struct HeaderView: View {
    let date: Date
    let streak: Int
    let isDark: Bool
    let introVisible: Bool
    let onToggleTheme: () -> Void
    let onThemeButtonFrame: (CGRect) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ZenHabit")
                    .font(.display(.largeTitle))
                    .tracking(-0.6)
                    .foregroundStyle(Theme.text)
                    .accessibilityAddTraits(.isHeader)
                Text(date, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textMuted)
            }
            .fadeUpIn(introVisible, delay: 0)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                ThemeToggleButton(isDark: isDark, action: onToggleTheme)
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .global)
                    } action: { frame in
                        onThemeButtonFrame(frame)
                    }
                StreakPill(streak: streak)
            }
            .fadeUpIn(introVisible, delay: 0.07)
        }
    }
}

/// Moon in light mode, sun in dark mode; they spin and cross-fade into each other.
struct ThemeToggleButton: View {
    let isDark: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(systemName: "moon")
                    .opacity(isDark ? 0 : 1)
                    .rotationEffect(.degrees(isDark ? 90 : 0))
                    .scaleEffect(isDark ? 0.3 : 1)
                Image(systemName: "sun.max")
                    .opacity(isDark ? 1 : 0)
                    .rotationEffect(.degrees(isDark ? 0 : -90))
                    .scaleEffect(isDark ? 1 : 0.3)
            }
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(Theme.textMuted)
            .frame(width: 44, height: 44)
            .background {
                Circle()
                    .fill(Theme.surface)
                    .zenShadow(.small)
            }
            .overlay {
                Circle().strokeBorder(Theme.border, lineWidth: 1)
            }
            .contentShape(Circle())
            .animation(.spring(response: 0.6, dampingFraction: 0.6), value: isDark)
        }
        .buttonStyle(PressableStyle(scale: 0.94))
        .hoverEffect(.highlight)
        .accessibilityLabel(isDark ? "Switch to light mode" : "Switch to dark mode")
    }
}

/// Days in a row with every habit done. The flame flickers while a streak is alive.
struct StreakPill: View {
    let streak: Int
    @State private var popPeak: Double = 1.45
    @State private var pops = 0

    var body: some View {
        HStack(spacing: 6) {
            FlameIcon(active: streak > 0, size: 17)
                .keyframeAnimator(initialValue: 1.0, trigger: pops) { content, scale in
                    content.scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(popPeak, duration: 0.24)
                        SpringKeyframe(1.0, duration: 0.36)
                    }
                }
            Text("\(streak)")
                .font(.callout.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Theme.text)
                .contentTransition(.numericText(value: Double(streak)))
                .animation(Motion.spring(0.52), value: streak)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
        .background {
            Capsule()
                .fill(Theme.surface)
                .zenShadow(.small)
        }
        .overlay {
            Capsule().strokeBorder(Theme.border, lineWidth: 1)
        }
        .onChange(of: streak) { oldValue, newValue in
            popPeak = newValue > oldValue ? 1.45 : 0.8
            pops += 1
        }
        .help("\(streak)-day streak with every habit done")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(streak) day streak")
        .accessibilityHint("Days in a row with every habit done")
    }
}

struct FlameIcon: View {
    let active: Bool
    var size: CGFloat = 16
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Flicker: CaseIterable {
        case rest, rise, dip

        var scale: Double {
            switch self {
            case .rest: return 1
            case .rise: return 1.06
            case .dip: return 0.98
            }
        }

        var angle: Double {
            switch self {
            case .rest: return 0
            case .rise: return -3
            case .dip: return 2
            }
        }

        /// How long it takes to arrive at this phase (2.4s loop in total).
        var duration: Double {
            switch self {
            case .rest: return 0.72
            case .rise: return 0.96
            case .dip: return 0.72
            }
        }
    }

    private var flickers: Bool { active && !reduceMotion }

    var body: some View {
        ZStack {
            Image(systemName: "flame.fill")
                .foregroundStyle(Theme.flame.opacity(active ? 0.25 : 0))
            Image(systemName: "flame")
                .foregroundStyle(active ? Theme.flame : Theme.textMuted)
        }
        .font(.system(size: size, weight: .semibold))
        .phaseAnimator(Flicker.allCases) { content, phase in
            content
                .scaleEffect(flickers ? phase.scale : 1, anchor: UnitPoint(x: 0.5, y: 0.9))
                .rotationEffect(.degrees(flickers ? phase.angle : 0), anchor: UnitPoint(x: 0.5, y: 0.9))
        } animation: { phase in
            .easeInOut(duration: phase.duration)
        }
        .animation(Motion.ease(0.25), value: active)
        .accessibilityHidden(true)
    }
}
