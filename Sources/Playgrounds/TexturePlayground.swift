import SwiftUI
import Combine

public struct SandGrain: Identifiable {
    public let id: Int
    public var pos: CGPoint
    public var origin: CGPoint
    public var vel: CGPoint = .zero
    public var size: CGFloat
    public var alpha: Double
}

public struct WaterRing: Identifiable {
    public let id = UUID()
    public var center: CGPoint
    public var radius: CGFloat = 8
    public var alpha: Double = 0.9
}

public struct TexturePlayground: View {
    @ObservedObject var appState: AppState

    // Drag & Touch tracking
    @State private var dragPosition: CGPoint = .zero
    @State private var isTouching: Bool = false
    @State private var dragSpeed: CGFloat = 0.0
    @State private var lastMoveTime: Date = Date()
    @State private var lastPoint: CGPoint = .zero

    // Corduroy state
    @State private var lastRidgeIndex: Int = -1
    @State private var highlightedRidgeIndex: Int? = nil

    // Sand state
    @State private var sandGrains: [SandGrain] = []
    @State private var lastSandDistance: CGFloat = 0.0
    @State private var lastSandPoint: CGPoint = .zero

    // Magnetic grid state
    private let gridStep: CGFloat = 55.0
    @State private var lastGridCell: (Int, Int) = (-1, -1)
    @State private var activeMagnetNode: CGPoint? = nil

    // Vinyl state
    @State private var vinylAngle: Double = 0.0
    @State private var lastVinylAngle: Double = 0.0
    @State private var lastVinylTickAngle: Double = 0.0

    // Water ripple state
    @State private var waterRings: [WaterRing] = []
    @State private var lastWaterPoint: CGPoint = .zero

    private let animationTimer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        GeometryReader { geo in
            VStack(spacing: 12) {
                // Top Material Selector Cards (PROMINENT & CLICKABLE)
                HStack(spacing: 10) {
                    ForEach(TextureType.allCases) { texture in
                        let isSelected = appState.selectedTexture == texture
                        Button(action: {
                            appState.setTexture(texture)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: texture.icon)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(isSelected ? .white : texture.accentColor)

                                Text(texture.title)
                                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                    .foregroundStyle(isSelected ? .white : .white.opacity(0.8))

                                Text(texture.shortcutNumber)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .white.opacity(0.4))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(isSelected ? 0.25 : 0.08)))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isSelected ? texture.accentColor.opacity(0.85) : Color(white: 0.12).opacity(0.7))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(isSelected ? Color.white.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .shadow(color: isSelected ? texture.accentColor.opacity(0.4) : .clear, radius: 10)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                // Subtitle Hint
                Text(appState.selectedTexture.hint)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.top, 2)

                // Interactive Canvas Container
                GeometryReader { canvasGeo in
                    ZStack {
                        // Background Material Visual
                        switch appState.selectedTexture {
                        case .corduroy:
                            corduroyCanvas(size: canvasGeo.size)
                        case .sand:
                            sandCanvas(size: canvasGeo.size)
                        case .magnetic:
                            magneticCanvas(size: canvasGeo.size)
                        case .vinyl:
                            vinylCanvas(size: canvasGeo.size)
                        case .water:
                            waterCanvas(size: canvasGeo.size)
                        }

                        // Active Stylus / Finger Puck Indicator
                        if isTouching {
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.85), lineWidth: 2)
                                    .background(Circle().fill(appState.selectedTexture.accentColor.opacity(0.3)))
                                    .frame(width: 46, height: 46)

                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 8, height: 8)
                            }
                            .position(dragPosition)
                            .allowsHitTesting(false)
                        }

                        // Trackpad Indirect Touch Bridge
                        TrackpadInputView(
                            onTouchUpdated: { touches in
                                if let first = touches.first {
                                    isTouching = true
                                    processInput(at: first.screenPos, in: canvasGeo.size)
                                }
                            },
                            onMouseMoved: { point, _, _ in
                                if !isTouching {
                                    dragPosition = point
                                }
                            },
                            onMouseDown: { point, _ in
                                isTouching = true
                                processInput(at: point, in: canvasGeo.size)
                            },
                            onMouseUp: { _ in
                                isTouching = false
                            }
                        )

                        // Native SwiftUI DragGesture for 100% Guaranteed Mouse/Trackpad Dragging
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        isTouching = true
                                        processInput(at: value.location, in: canvasGeo.size)
                                    }
                                    .onEnded { _ in
                                        isTouching = false
                                    }
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1.5)
                    )
                    .onAppear {
                        initSand(in: canvasGeo.size)
                    }
                    .onChange(of: canvasGeo.size) { newSize in
                        initSand(in: newSize)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .onReceive(animationTimer) { _ in
                updatePhysics()
            }
        }
    }

    // MARK: - Corduroy Canvas

    private func corduroyCanvas(size: CGSize) -> some View {
        Canvas { ctx, cSize in
            let spacing = appState.ridgeSpacing
            let count = Int(cSize.width / spacing)
            for i in 0...count {
                let x = CGFloat(i) * spacing
                let isHighlighted = highlightedRidgeIndex == i

                let path = Path { p in
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: cSize.height))
                }

                // Ridge body
                let ridgeColor = isHighlighted ? Color.cyan : Color.purple.opacity(0.35)
                ctx.stroke(path, with: .color(ridgeColor), lineWidth: isHighlighted ? 6 : 3.5)

                // Highlight specular
                let hlPath = Path { p in
                    p.move(to: CGPoint(x: x - 1, y: 0))
                    p.addLine(to: CGPoint(x: x - 1, y: cSize.height))
                }
                ctx.stroke(hlPath, with: .color(isHighlighted ? Color.white : Color.white.opacity(0.2)), lineWidth: 1.5)
            }
        }
        .background(Color(red: 0.12, green: 0.08, blue: 0.18))
    }

    // MARK: - Sand Canvas

    private func sandCanvas(size: CGSize) -> some View {
        Canvas { ctx, _ in
            for g in sandGrains {
                let rect = CGRect(x: g.pos.x - g.size / 2, y: g.pos.y - g.size / 2, width: g.size, height: g.size)
                ctx.opacity = g.alpha
                ctx.fill(Circle().path(in: rect), with: .color(Color(red: 0.95, green: 0.82, blue: 0.55)))
            }
        }
        .background(Color(red: 0.16, green: 0.12, blue: 0.08))
    }

    private func initSand(in size: CGSize) {
        guard size.width > 50 && size.height > 50 else { return }
        var grains: [SandGrain] = []
        let count = 340
        for i in 0..<count {
            let rx = CGFloat.random(in: 20...(size.width - 20))
            let ry = CGFloat.random(in: 20...(size.height - 20))
            grains.append(
                SandGrain(
                    id: i,
                    pos: CGPoint(x: rx, y: ry),
                    origin: CGPoint(x: rx, y: ry),
                    size: CGFloat.random(in: 2.5...5.5),
                    alpha: Double.random(in: 0.4...0.9)
                )
            )
        }
        sandGrains = grains
    }

    // MARK: - Magnetic Grid Canvas

    private func magneticCanvas(size: CGSize) -> some View {
        Canvas { ctx, cSize in
            let cols = Int(cSize.width / gridStep)
            let rows = Int(cSize.height / gridStep)

            for c in 0...cols {
                for r in 0...rows {
                    let pt = CGPoint(
                        x: CGFloat(c) * gridStep + (cSize.width.truncatingRemainder(dividingBy: gridStep)) / 2,
                        y: CGFloat(r) * gridStep + (cSize.height.truncatingRemainder(dividingBy: gridStep)) / 2
                    )

                    let isNearby = activeMagnetNode != nil && hypot(pt.x - (activeMagnetNode?.x ?? 0), pt.y - (activeMagnetNode?.y ?? 0)) < 12

                    let rect = CGRect(x: pt.x - (isNearby ? 7 : 3), y: pt.y - (isNearby ? 7 : 3), width: isNearby ? 14 : 6, height: isNearby ? 14 : 6)
                    ctx.fill(Circle().path(in: rect), with: .color(isNearby ? Color.cyan : Color.cyan.opacity(0.4)))

                    let ring = CGRect(x: pt.x - 18, y: pt.y - 18, width: 36, height: 36)
                    ctx.stroke(Circle().path(in: ring), with: .color(isNearby ? Color.cyan.opacity(0.85) : Color.cyan.opacity(0.12)), lineWidth: isNearby ? 2 : 1)
                }
            }

            // Magnetic snap beam
            if let node = activeMagnetNode, isTouching {
                let beam = Path { p in
                    p.move(to: dragPosition)
                    p.addLine(to: node)
                }
                ctx.stroke(beam, with: .color(Color.cyan.opacity(0.7)), lineWidth: 2.5)
            }
        }
        .background(Color(red: 0.04, green: 0.08, blue: 0.14))
    }

    // MARK: - Vinyl Canvas

    private func vinylCanvas(size: CGSize) -> some View {
        let discSize = min(size.width * 0.72, size.height * 0.72)
        return ZStack {
            // Vinyl Record Disc
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.22), Color(white: 0.08), Color.black],
                        center: .center,
                        startRadius: 20,
                        endRadius: discSize / 2
                    )
                )
                .frame(width: discSize, height: discSize)
                .overlay(
                    // Grooves
                    ForEach(1..<15, id: \.self) { g in
                        Circle()
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                            .frame(width: discSize * (CGFloat(g) / 16.0) + 30, height: discSize * (CGFloat(g) / 16.0) + 30)
                    }
                )
                .overlay(
                    // Center label
                    Circle()
                        .fill(Color(red: 0.85, green: 0.25, blue: 0.35))
                        .frame(width: discSize * 0.32, height: discSize * 0.32)
                        .overlay(
                            VStack(spacing: 2) {
                                Image(systemName: "record.circle")
                                    .font(.headline)
                                Text("HAPTICA 33 RPM")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(.white)
                        )
                )
                .rotationEffect(.degrees(vinylAngle))
                .shadow(color: .black.opacity(0.65), radius: 20)

            // Tonearm
            VStack {
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(white: 0.45))
                        .frame(width: 8, height: discSize * 0.5)
                        .rotationEffect(.degrees(25))
                        .offset(x: -25, y: 20)
                }
                Spacer()
            }
            .frame(width: discSize, height: discSize)
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.07, green: 0.07, blue: 0.09))
    }

    // MARK: - Water Canvas

    private func waterCanvas(size: CGSize) -> some View {
        ZStack {
            Color(red: 0.04, green: 0.12, blue: 0.16)

            Canvas { ctx, _ in
                for ring in waterRings {
                    let rect = CGRect(
                        x: ring.center.x - ring.radius,
                        y: ring.center.y - ring.radius,
                        width: ring.radius * 2,
                        height: ring.radius * 2
                    )
                    ctx.opacity = ring.alpha
                    ctx.stroke(Circle().path(in: rect), with: .color(Color(red: 0.3, green: 0.9, blue: 0.85)), lineWidth: 2)
                }
            }
        }
    }

    // MARK: - Physics Loop

    private func updatePhysics() {
        let dt: CGFloat = 0.016

        // Sand physics
        if appState.selectedTexture == .sand && !sandGrains.isEmpty {
            for i in 0..<sandGrains.count {
                if isTouching {
                    let dx = sandGrains[i].pos.x - dragPosition.x
                    let dy = sandGrains[i].pos.y - dragPosition.y
                    let dist = sqrt(dx * dx + dy * dy)
                    if dist < 50.0 && dist > 0.01 {
                        let force = (50.0 - dist) * 14.0
                        sandGrains[i].vel.x += (dx / dist) * force
                        sandGrains[i].vel.y += (dy / dist) * force
                    }
                }

                let ox = sandGrains[i].origin.x - sandGrains[i].pos.x
                let oy = sandGrains[i].origin.y - sandGrains[i].pos.y
                sandGrains[i].vel.x += ox * 2.8 * dt
                sandGrains[i].vel.y += oy * 2.8 * dt

                sandGrains[i].pos.x += sandGrains[i].vel.x * dt
                sandGrains[i].pos.y += sandGrains[i].vel.y * dt

                sandGrains[i].vel.x *= 0.86
                sandGrains[i].vel.y *= 0.86
            }
        }

        // Water ripple physics
        if appState.selectedTexture == .water && !waterRings.isEmpty {
            var updated: [WaterRing] = []
            for var ring in waterRings {
                ring.radius += 90.0 * dt
                ring.alpha -= 0.035
                if ring.alpha > 0.02 {
                    updated.append(ring)
                }
            }
            waterRings = updated
        }
    }

    // MARK: - Input Processing

    private func processInput(at point: CGPoint, in size: CGSize) {
        let now = Date()
        let dt = max(0.001, now.timeIntervalSince(lastMoveTime))
        let dist = hypot(point.x - lastPoint.x, point.y - lastPoint.y)
        dragSpeed = dist / CGFloat(dt)
        lastMoveTime = now
        lastPoint = point
        dragPosition = point

        switch appState.selectedTexture {
        case .corduroy:
            let spacing = appState.ridgeSpacing
            let ridge = Int(point.x / spacing)
            if ridge != lastRidgeIndex {
                lastRidgeIndex = ridge
                highlightedRidgeIndex = ridge
                appState.totalTextureCrossings += 1

                let pitch = Float(1.0 + min(0.8, Double(dragSpeed) / 1200.0))
                appState.haptics.trigger(.lightClick)
                appState.audio.play(.ratchetTick(pitch: pitch))

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    if self.highlightedRidgeIndex == ridge {
                        self.highlightedRidgeIndex = nil
                    }
                }
            }

        case .sand:
            let sandDist = hypot(point.x - lastSandPoint.x, point.y - lastSandPoint.y)
            lastSandDistance += sandDist
            lastSandPoint = point

            if lastSandDistance > 12.0 {
                lastSandDistance = 0
                appState.totalTextureCrossings += 1
                if Double.random(in: 0...1) > 0.25 {
                    appState.haptics.trigger(.granular)
                    appState.audio.play(.sandGrain)
                }
            }

        case .magnetic:
            let offsetX = (size.width.truncatingRemainder(dividingBy: gridStep)) / 2
            let offsetY = (size.height.truncatingRemainder(dividingBy: gridStep)) / 2

            let col = Int(round((point.x - offsetX) / gridStep))
            let row = Int(round((point.y - offsetY) / gridStep))

            let nodeX = CGFloat(col) * gridStep + offsetX
            let nodeY = CGFloat(row) * gridStep + offsetY
            let targetNode = CGPoint(x: nodeX, y: nodeY)

            activeMagnetNode = targetNode

            if col != lastGridCell.0 || row != lastGridCell.1 {
                lastGridCell = (col, row)
                appState.totalTextureCrossings += 1
                appState.haptics.trigger(.mediumClick)
                appState.audio.play(.ratchetTick(pitch: 0.85))
            }

        case .vinyl:
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let dx = point.x - center.x
            let dy = point.y - center.y
            let currentAngle = atan2(dy, dx) * 180.0 / .pi

            if lastVinylAngle != 0 {
                var delta = currentAngle - lastVinylAngle
                if delta > 180 { delta -= 360 }
                if delta < -180 { delta += 360 }

                vinylAngle += delta

                if abs(vinylAngle - lastVinylTickAngle) > 4.5 {
                    lastVinylTickAngle = vinylAngle
                    appState.totalTextureCrossings += 1
                    appState.haptics.trigger(.lightClick)
                    let pitch = Float(1.1 + min(0.7, abs(delta) / 10.0))
                    appState.audio.play(.ratchetTick(pitch: pitch))
                }
            }
            lastVinylAngle = currentAngle

        case .water:
            let waterDist = hypot(point.x - lastWaterPoint.x, point.y - lastWaterPoint.y)
            if waterDist > 25.0 {
                lastWaterPoint = point
                waterRings.append(WaterRing(center: point))
                appState.totalTextureCrossings += 1
                appState.haptics.trigger(.lightClick)
                appState.audio.play(.bubblePop(pitch: 1.5))
            }
        }
    }
}
