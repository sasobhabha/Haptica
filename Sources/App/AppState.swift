import SwiftUI
import Combine

public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var selectedTexture: TextureType = .corduroy
    @Published public var isAlwaysOnTop: Bool = false {
        didSet {
            updateWindowLevel()
        }
    }
    @Published public var showTouchOverlay: Bool = true
    @Published public var activeTouches: [TouchPoint] = []
    @Published public var totalTextureCrossings: Int = 0

    // Texture Parameters
    @Published public var ridgeSpacing: CGFloat = 26.0

    // References to core singletons
    public let haptics = HapticEngine.shared
    public let audio = SoundSynthesizer.shared

    private init() {}

    public func setTexture(_ texture: TextureType) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            selectedTexture = texture
        }
        haptics.trigger(.mediumClick)
        audio.play(.ratchetTick(pitch: 1.2))
    }

    private func updateWindowLevel() {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first(where: { $0.isKeyWindow || $0.isVisible }) {
                window.level = self.isAlwaysOnTop ? .floating : .normal
            }
        }
    }
}
