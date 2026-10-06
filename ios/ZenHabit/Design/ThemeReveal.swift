import UIKit

/// The circular light/dark reveal: freezes a snapshot of the old theme on top of the window,
/// switches the theme underneath, then punches a growing hole in the snapshot from `center`.
enum ThemeReveal {
    @MainActor
    static func perform(from center: CGPoint, duration: CFTimeInterval = 0.7, apply: () -> Void) {
        guard let window = activeWindow(), let snapshot = window.snapshotView(afterScreenUpdates: false) else {
            apply()
            return
        }
        let bounds = window.bounds
        snapshot.frame = bounds
        snapshot.isUserInteractionEnabled = false
        window.addSubview(snapshot)

        apply()

        let radius = hypot(max(center.x, bounds.width - center.x), max(center.y, bounds.height - center.y))
        let mask = CAShapeLayer()
        mask.frame = bounds
        mask.fillRule = .evenOdd
        mask.path = holePath(in: bounds, center: center, radius: radius)
        snapshot.layer.mask = mask

        let grow = CABasicAnimation(keyPath: "path")
        grow.fromValue = holePath(in: bounds, center: center, radius: 0.5)
        grow.toValue = mask.path
        grow.duration = duration
        grow.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)

        CATransaction.begin()
        CATransaction.setCompletionBlock { snapshot.removeFromSuperview() }
        mask.add(grow, forKey: "reveal")
        CATransaction.commit()
    }

    /// The whole window minus a circle (even-odd fill leaves the circle transparent).
    private static func holePath(in rect: CGRect, center: CGPoint, radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.addRect(rect)
        path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        return path
    }

    @MainActor
    private static func activeWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.filter { $0.activationState == .foregroundActive }.flatMap(\.windows)
        return windows.first(where: \.isKeyWindow) ?? windows.first
    }
}
