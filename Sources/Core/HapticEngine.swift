import AppKit
import Foundation
import Combine

public enum HapticFeedbackType: Equatable, Sendable {
    case lightClick      // subtle tick (textures, fine detents)
    case mediumClick     // bubble pop, standard notch
    case heavyClick      // vault clunk, 808 bass, wall bounce
    case doubleClick     // lock unlock, double stage
    case detent          // gear tooth engagement
    case granular        // micro sand grain / grit
    case raw(Int32)      // raw actuator ID 1-6
}

public final class HapticEngine: ObservableObject {
    public static let shared = HapticEngine()

    @Published public var isHardwareActuatorAvailable: Bool = false
    @Published public var totalActuations: Int = 0
    @Published public var lastActuationTime: Date = Date()
    @Published public var intensity: Double = 1.0 // 0.0 (off) to 1.5 (boost)
    @Published public var isEnabled: Bool = true

    // Low-level MultitouchSupport handles
    private typealias MTDeviceRef = UnsafeMutableRawPointer
    private typealias MTActuatorRef = UnsafeMutableRawPointer

    private var mtActuator: MTActuatorRef?
    private var mtActuatorActuateFunc: (@convention(c) (MTActuatorRef, Int32, UInt32, Float, Float) -> Int32)?
    private var mtActuatorCloseFunc: (@convention(c) (MTActuatorRef) -> Int32)?

    private var lastTriggerUptime: TimeInterval = 0
    private let minimumInterval: TimeInterval = 0.005 // 5ms throttle to prevent saturation
    private let queue = DispatchQueue(label: "com.antigravity.haptica.engine", qos: .userInteractive)

    private init() {
        setupLowLevelActuator()
    }

    deinit {
        if let act = mtActuator, let closeFunc = mtActuatorCloseFunc {
            _ = closeFunc(act)
        }
    }

    private func setupLowLevelActuator() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW) else {
            print("[HapticEngine] MultitouchSupport framework not found, using AppKit fallback")
            isHardwareActuatorAvailable = false
            return
        }

        guard let createDevPtr = dlsym(handle, "MTDeviceCreateDefault"),
              let getDevIDPtr = dlsym(handle, "MTDeviceGetDeviceID"),
              let createActuatorPtr = dlsym(handle, "MTActuatorCreateFromDeviceID"),
              let openActuatorPtr = dlsym(handle, "MTActuatorOpen"),
              let actuatePtr = dlsym(handle, "MTActuatorActuate"),
              let closePtr = dlsym(handle, "MTActuatorClose") else {
            print("[HapticEngine] Multitouch symbols missing, using AppKit fallback")
            isHardwareActuatorAvailable = false
            return
        }

        let MTDeviceCreateDefault = unsafeBitCast(createDevPtr, to: (@convention(c) () -> MTDeviceRef?).self)
        let MTDeviceGetDeviceID = unsafeBitCast(getDevIDPtr, to: (@convention(c) (MTDeviceRef, UnsafeMutablePointer<UInt64>) -> Int32).self)
        let MTActuatorCreateFromDeviceID = unsafeBitCast(createActuatorPtr, to: (@convention(c) (UInt64) -> MTActuatorRef?).self)
        let MTActuatorOpen = unsafeBitCast(openActuatorPtr, to: (@convention(c) (MTActuatorRef) -> Int32).self)
        let MTActuatorActuate = unsafeBitCast(actuatePtr, to: (@convention(c) (MTActuatorRef, Int32, UInt32, Float, Float) -> Int32).self)
        let MTActuatorClose = unsafeBitCast(closePtr, to: (@convention(c) (MTActuatorRef) -> Int32).self)

        if let dev = MTDeviceCreateDefault() {
            var devID: UInt64 = 0
            let res = MTDeviceGetDeviceID(dev, &devID)
            if res == 0, let actuator = MTActuatorCreateFromDeviceID(devID) {
                let openRes = MTActuatorOpen(actuator)
                if openRes == 0 {
                    self.mtActuator = actuator
                    self.mtActuatorActuateFunc = MTActuatorActuate
                    self.mtActuatorCloseFunc = MTActuatorClose
                    self.isHardwareActuatorAvailable = true
                    print("[HapticEngine] Low-level hardware actuator initialized successfully! (DeviceID: \(devID))")
                    return
                }
            }
        }

        print("[HapticEngine] Falling back to standard AppKit NSHapticFeedbackManager")
        self.isHardwareActuatorAvailable = false
    }

    /// Primary trigger entry point
    public func trigger(_ type: HapticFeedbackType) {
        guard isEnabled && intensity > 0.05 else { return }

        let now = ProcessInfo.processInfo.systemUptime
        // Granular allows higher rate, standard clicks throttle slightly
        let minTime = (type == .granular) ? 0.003 : minimumInterval
        if now - lastTriggerUptime < minTime {
            return
        }
        lastTriggerUptime = now

        queue.async { [weak self] in
            guard let self = self else { return }
            self.executeFeedback(type)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.totalActuations += 1
            self.lastActuationTime = Date()
        }
    }

    private func executeFeedback(_ type: HapticFeedbackType) {
        let currentIntensity = intensity

        // 1. Try hardware actuator first if available
        if let actuator = mtActuator, let actuate = mtActuatorActuateFunc {
            let actuatorID: Int32
            switch type {
            case .lightClick, .granular:
                actuatorID = 1
            case .mediumClick, .detent:
                actuatorID = 2
            case .heavyClick:
                actuatorID = 3
            case .doubleClick:
                actuatorID = 4
            case .raw(let id):
                actuatorID = id
            }

            _ = actuate(actuator, actuatorID, 0, 0.0, 0.0)

            // Boost effect: if intensity > 1.2, fire a micro follow-up pulse
            if currentIntensity > 1.2 && (type == .heavyClick || type == .mediumClick) {
                usleep(14000) // 14ms
                _ = actuate(actuator, 1, 0, 0.0, 0.0)
            }
            return
        }

        // 2. High-level AppKit fallback
        let pattern: NSHapticFeedbackManager.FeedbackPattern
        switch type {
        case .lightClick, .granular:
            pattern = .alignment
        case .mediumClick, .detent:
            pattern = .levelChange
        case .heavyClick, .doubleClick, .raw:
            pattern = .generic
        }

        DispatchQueue.main.async {
            NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)

            if currentIntensity > 1.2 && (type == .heavyClick || type == .mediumClick) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.015) {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                }
            }
        }
    }

    /// Rhythmic pulse burst (for purr, heartbeat, spin-down)
    public func pulseTrain(count: Int, interval: TimeInterval, type: HapticFeedbackType = .lightClick) {
        guard isEnabled && intensity > 0.05 else { return }
        for i in 0..<count {
            let delay = Double(i) * interval
            queue.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.executeFeedback(type)
            }
        }
    }
}
