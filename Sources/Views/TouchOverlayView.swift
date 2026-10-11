import SwiftUI

public struct TouchOverlayView: View {
    public let touches: [TouchPoint]
    public let showTrails: Bool

    public init(touches: [TouchPoint], showTrails: Bool = true) {
        self.touches = touches
        self.showTrails = showTrails
    }

    public var body: some View {
        Canvas { ctx, size in
            for touch in touches {
                let pt = touch.screenPos
                let radius: CGFloat = 20 + touch.pressure * 18

                // Outer glow halo
                let haloRect = CGRect(x: pt.x - radius * 1.6, y: pt.y - radius * 1.6, width: radius * 3.2, height: radius * 3.2)
                ctx.fill(Circle().path(in: haloRect), with: .color(Color.cyan.opacity(0.18)))

                // Force ring
                let ringRect = CGRect(x: pt.x - radius, y: pt.y - radius, width: radius * 2, height: radius * 2)
                ctx.stroke(Circle().path(in: ringRect), with: .color(Color.white.opacity(0.85)), lineWidth: 2)

                // Inner core dot
                let coreRect = CGRect(x: pt.x - 5, y: pt.y - 5, width: 10, height: 10)
                ctx.fill(Circle().path(in: coreRect), with: .color(.cyan))
            }
        }
        .allowsHitTesting(false)
    }
}
