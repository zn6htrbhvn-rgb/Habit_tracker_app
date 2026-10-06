import SwiftUI

/// One celebration: 48 pieces of confetti in the habits' colors, thrown from the progress card.
struct ConfettiBurst: Identifiable, Equatable {
    struct Piece {
        let color: Color
        let isRound: Bool
        /// Horizontal start, as a fraction of the screen width.
        let startX: CGFloat
        let width: CGFloat
        let height: CGFloat
        /// Total sideways drift, as a fraction of the screen width.
        let drift: CGFloat
        /// How high it pops before falling (negative is up).
        let lift: CGFloat
        let spin: CGFloat
        let duration: CGFloat
        let delay: CGFloat
    }

    let id = UUID()
    /// Where the burst starts, in window coordinates.
    let originY: CGFloat
    let pieces: [Piece]

    init(originY: CGFloat, colors: [String]) {
        self.originY = originY
        let palette = colors.isEmpty ? HabitPalette.colors.map(\.hex) : colors
        pieces = (0..<48).map { index in
            let size = CGFloat.random(in: 6...12)
            return Piece(
                color: Color(uiColor: UIColor(hex: palette[index % palette.count])),
                isRound: Double.random(in: 0..<1) < 0.35,
                startX: CGFloat.random(in: 0.45...0.55),
                width: size,
                height: size * CGFloat.random(in: 1...1.6),
                drift: CGFloat.random(in: -0.45...0.45),
                lift: -CGFloat.random(in: 60...220),
                spin: CGFloat.random(in: -450...450),
                duration: CGFloat.random(in: 1.1...1.9),
                delay: CGFloat.random(in: 0...0.12)
            )
        }
    }

    static func == (lhs: ConfettiBurst, rhs: ConfettiBurst) -> Bool { lhs.id == rhs.id }
}

struct ConfettiView: View {
    let burst: ConfettiBurst
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = CGFloat(timeline.date.timeIntervalSince(start))
                for piece in burst.pieces {
                    draw(piece, elapsed: elapsed, in: context, size: size)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Pops up and out for the first quarter, then tumbles down 70% of the screen while fading.
    private func draw(_ piece: ConfettiBurst.Piece, elapsed: CGFloat, in context: GraphicsContext, size: CGSize) {
        let t = (elapsed - piece.delay) / piece.duration
        guard t >= 0, t < 1 else { return }

        let drift = piece.drift * size.width
        let fall = size.height * 0.7
        let x: CGFloat, y: CGFloat, spin: CGFloat, scale: CGFloat, opacity: CGFloat
        if t < 0.25 {
            let k = easeOut(t / 0.25)
            x = drift * 0.6 * k
            y = piece.lift * k
            spin = piece.spin * 0.4 * k
            scale = 0.6 + 0.4 * k
            opacity = 1
        } else {
            let k = easeOut((t - 0.25) / 0.75)
            x = drift * (0.6 + 0.4 * k)
            y = piece.lift + (fall - piece.lift) * k
            spin = piece.spin * (0.4 + 0.6 * k)
            scale = 1
            opacity = 1 - k
        }

        let originY = min(max(burst.originY, 0), size.height)
        var layer = context
        layer.opacity = Double(opacity)
        layer.translateBy(x: size.width * piece.startX + x, y: originY + y)
        layer.rotate(by: .degrees(Double(spin)))
        layer.scaleBy(x: scale, y: scale)
        let rect = CGRect(x: -piece.width / 2, y: -piece.height / 2, width: piece.width, height: piece.height)
        let path = piece.isRound ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 2)
        layer.fill(path, with: .color(piece.color))
    }

    private func easeOut(_ x: CGFloat) -> CGFloat {
        let inverse = 1 - x
        return 1 - inverse * inverse * inverse
    }
}
