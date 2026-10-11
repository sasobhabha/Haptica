import AppKit
import SwiftUI

public struct TrackpadInputView: NSViewRepresentable {
    public var onTouchUpdated: ([TouchPoint]) -> Void
    public var onMouseMoved: (CGPoint, CGFloat, Int) -> Void // (point, pressure, stage)
    public var onMouseDown: (CGPoint, CGFloat) -> Void
    public var onMouseUp: (CGPoint) -> Void

    public init(
        onTouchUpdated: @escaping ([TouchPoint]) -> Void,
        onMouseMoved: @escaping (CGPoint, CGFloat, Int) -> Void = { _, _, _ in },
        onMouseDown: @escaping (CGPoint, CGFloat) -> Void = { _, _ in },
        onMouseUp: @escaping (CGPoint) -> Void = { _ in }
    ) {
        self.onTouchUpdated = onTouchUpdated
        self.onMouseMoved = onMouseMoved
        self.onMouseDown = onMouseDown
        self.onMouseUp = onMouseUp
    }

    public func makeNSView(context: Context) -> TrackpadContainerView {
        let view = TrackpadContainerView()
        view.onTouchUpdated = onTouchUpdated
        view.onMouseMoved = onMouseMoved
        view.onMouseDown = onMouseDown
        view.onMouseUp = onMouseUp
        return view
    }

    public func updateNSView(_ nsView: TrackpadContainerView, context: Context) {
        nsView.onTouchUpdated = onTouchUpdated
        nsView.onMouseMoved = onMouseMoved
        nsView.onMouseDown = onMouseDown
        nsView.onMouseUp = onMouseUp
    }
}

public final class TrackpadContainerView: NSView {
    var onTouchUpdated: (([TouchPoint]) -> Void)?
    var onMouseMoved: ((CGPoint, CGFloat, Int) -> Void)?
    var onMouseDown: ((CGPoint, CGFloat) -> Void)?
    var onMouseUp: ((CGPoint) -> Void)?

    private var activeTouches: [ObjectIdentifier: TouchPoint] = [:]
    private var trackingArea: NSTrackingArea?
    private var identityToID: [ObjectIdentifier: Int] = [:]
    private var nextTouchID: Int = 1
    private var isMouseDown: Bool = false

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        allowedTouchTypes = [.indirect]
    }

    public override var acceptsFirstResponder: Bool {
        return true
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let options: NSTrackingArea.Options = [
            .mouseMoved,
            .mouseEnteredAndExited,
            .activeAlways,
            .inVisibleRect
        ]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        self.trackingArea = area
    }

    // MARK: - Indirect Touch Handling (Trackpad multi-touch)

    public override func touchesBegan(with event: NSEvent) {
        handleTouches(event: event, phase: .began)
    }

    public override func touchesMoved(with event: NSEvent) {
        handleTouches(event: event, phase: .moved)
    }

    public override func touchesEnded(with event: NSEvent) {
        handleTouches(event: event, phase: .ended)
    }

    public override func touchesCancelled(with event: NSEvent) {
        handleTouches(event: event, phase: .cancelled)
    }

    private func handleTouches(event: NSEvent, phase: TouchPhase) {
        let touches = event.touches(matching: .touching, in: self)
        let bounds = self.bounds

        var currentPoints: [TouchPoint] = []

        for touch in touches {
            let ident = ObjectIdentifier(touch.identity as AnyObject)
            let touchID: Int
            if let existingID = identityToID[ident] {
                touchID = existingID
            } else {
                touchID = nextTouchID
                identityToID[ident] = touchID
                nextTouchID += 1
            }

            let norm = touch.normalizedPosition
            // Convert trackpad normalized position (bottom-left origin) to view space (top-left origin for SwiftUI)
            let screenX = norm.x * bounds.width
            let screenY = (1.0 - norm.y) * bounds.height

            var point = TouchPoint(
                id: touchID,
                normalizedPos: norm,
                screenPos: CGPoint(x: screenX, y: screenY),
                phase: phase,
                pressure: CGFloat(event.pressure)
            )

            if let prev = activeTouches[ident] {
                let dt = max(0.001, point.timestamp - prev.timestamp)
                let vx = (point.screenPos.x - prev.screenPos.x) / CGFloat(dt)
                let vy = (point.screenPos.y - prev.screenPos.y) / CGFloat(dt)
                point.velocity = CGPoint(x: vx, y: vy)
            }

            activeTouches[ident] = point
            currentPoints.append(point)
        }

        // Clean up ended touches
        if phase == .ended || phase == .cancelled {
            let activeIdents = Set(touches.map { ObjectIdentifier($0.identity as AnyObject) })
            for key in identityToID.keys where !activeIdents.contains(key) {
                identityToID.removeValue(forKey: key)
                activeTouches.removeValue(forKey: key)
            }
        }

        onTouchUpdated?(currentPoints)
    }

    // MARK: - Mouse & Force Touch Pointer Handling

    public override func mouseMoved(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        let swiftLoc = CGPoint(x: loc.x, y: bounds.height - loc.y)
        let pressure = CGFloat(event.pressure)
        let stage = event.stage
        onMouseMoved?(swiftLoc, pressure, stage)

        if activeTouches.isEmpty {
            // Synthesize single touch point from cursor if no multi-touch is reporting
            let normX = bounds.width > 0 ? loc.x / bounds.width : 0.5
            let normY = bounds.height > 0 ? (bounds.height - loc.y) / bounds.height : 0.5
            let pt = TouchPoint(
                id: 0,
                normalizedPos: CGPoint(x: normX, y: normY),
                screenPos: swiftLoc,
                phase: isMouseDown ? .moved : .stationary,
                pressure: pressure
            )
            onTouchUpdated?([pt])
        }
    }

    public override func mouseDown(with event: NSEvent) {
        isMouseDown = true
        let loc = convert(event.locationInWindow, from: nil)
        let swiftLoc = CGPoint(x: loc.x, y: bounds.height - loc.y)
        let pressure = max(0.2, CGFloat(event.pressure))
        onMouseDown?(swiftLoc, pressure)

        if activeTouches.isEmpty {
            let normX = bounds.width > 0 ? loc.x / bounds.width : 0.5
            let normY = bounds.height > 0 ? (bounds.height - loc.y) / bounds.height : 0.5
            let pt = TouchPoint(
                id: 0,
                normalizedPos: CGPoint(x: normX, y: normY),
                screenPos: swiftLoc,
                phase: .began,
                pressure: pressure
            )
            onTouchUpdated?([pt])
        }
    }

    public override func mouseDragged(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        let swiftLoc = CGPoint(x: loc.x, y: bounds.height - loc.y)
        let pressure = max(0.2, CGFloat(event.pressure))
        let stage = event.stage
        onMouseMoved?(swiftLoc, pressure, stage)

        if activeTouches.isEmpty {
            let normX = bounds.width > 0 ? loc.x / bounds.width : 0.5
            let normY = bounds.height > 0 ? (bounds.height - loc.y) / bounds.height : 0.5
            let pt = TouchPoint(
                id: 0,
                normalizedPos: CGPoint(x: normX, y: normY),
                screenPos: swiftLoc,
                phase: .moved,
                pressure: pressure
            )
            onTouchUpdated?([pt])
        }
    }

    public override func mouseUp(with event: NSEvent) {
        isMouseDown = false
        let loc = convert(event.locationInWindow, from: nil)
        let swiftLoc = CGPoint(x: loc.x, y: bounds.height - loc.y)
        onMouseUp?(swiftLoc)

        if activeTouches.isEmpty {
            let normX = bounds.width > 0 ? loc.x / bounds.width : 0.5
            let normY = bounds.height > 0 ? (bounds.height - loc.y) / bounds.height : 0.5
            let pt = TouchPoint(
                id: 0,
                normalizedPos: CGPoint(x: normX, y: normY),
                screenPos: swiftLoc,
                phase: .ended,
                pressure: 0
            )
            onTouchUpdated?([pt])
        }
    }
}
