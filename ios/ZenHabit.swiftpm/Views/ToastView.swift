import SwiftUI

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let undo: (() -> Void)?

    /// Undo stays available for 6 seconds; plain notes leave after 2.5.
    var duration: Double { undo == nil ? 2.5 : 6 }

    static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id }
}

/// The dark pill at the bottom ("Added …", "Deleted … Undo").
struct ToastView: View {
    let toast: Toast
    /// Bumped when a new toast replaces one that was still showing.
    let bump: Int
    let onUndo: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            Text(toast.message)
                .lineLimit(1)
                .truncationMode(.tail)
            if toast.undo != nil {
                Button(action: onUndo) {
                    Text("Undo")
                        .font(.subheadline.weight(.bold))
                        .underline()
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle(scale: 0.95))
            }
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(Theme.bg)
        .padding(.leading, 24)
        .padding(.trailing, toast.undo == nil ? 24 : 4)
        .padding(.vertical, 4)
        .frame(minHeight: 44)
        .background {
            Capsule()
                .fill(Theme.text)
                .zenShadow(.large)
        }
        .overlay(alignment: .bottom) {
            // Thin countdown showing how long Undo stays available.
            if toast.undo != nil && !reduceMotion {
                CountdownBar(duration: toast.duration)
                    .id(toast.id)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 5)
            }
        }
        .keyframeAnimator(initialValue: 1.0, trigger: bump) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(1.05, duration: 0.18)
                SpringKeyframe(1.0, duration: 0.27)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct CountdownBar: View {
    let duration: Double
    @State private var remaining: CGFloat = 1

    var body: some View {
        Capsule()
            .fill(Theme.bg.opacity(0.3))
            .frame(height: 2)
            .scaleEffect(x: remaining, y: 1, anchor: .leading)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(.linear(duration: duration)) { remaining = 0 }
            }
    }
}
