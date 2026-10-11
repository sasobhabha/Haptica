import Foundation
import CoreGraphics

public enum TouchPhase: Sendable {
    case began
    case moved
    case stationary
    case ended
    case cancelled
}

public struct TouchPoint: Identifiable, Sendable {
    public let id: Int
    public var normalizedPos: CGPoint // (0...1, 0...1), trackpad space
    public var screenPos: CGPoint     // Canvas coordinates
    public var phase: TouchPhase
    public var pressure: CGFloat      // 0.0 to 1.0
    public var velocity: CGPoint
    public var timestamp: TimeInterval

    public init(
        id: Int,
        normalizedPos: CGPoint,
        screenPos: CGPoint = .zero,
        phase: TouchPhase = .moved,
        pressure: CGFloat = 0.0,
        velocity: CGPoint = .zero,
        timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) {
        self.id = id
        self.normalizedPos = normalizedPos
        self.screenPos = screenPos
        self.phase = phase
        self.pressure = pressure
        self.velocity = velocity
        self.timestamp = timestamp
    }
}
