import SwiftUI

public enum TextureType: String, CaseIterable, Identifiable, Sendable {
    case corduroy = "Corduroy"
    case sand = "Sand & Grit"
    case magnetic = "Magnetic Grid"
    case vinyl = "Vinyl Scratch"
    case water = "Water Ripples"

    public var id: String { rawValue }

    public var title: String { rawValue }

    public var icon: String {
        switch self {
        case .corduroy: return "slider.vertical.3"
        case .sand: return "sparkles"
        case .magnetic: return "circle.hexagongrid.fill"
        case .vinyl: return "record.circle.fill"
        case .water: return "drop.fill"
        }
    }

    public var hint: String {
        switch self {
        case .corduroy: return "Drag across ridges to feel corrugated texture detents"
        case .sand: return "Swirl fingers or drag mouse to feel granular sand grains"
        case .magnetic: return "Glide across nodes to feel magnetic attractor wells snap"
        case .vinyl: return "Scratch the record back and forth like a real DJ turntable"
        case .water: return "Slide across the fluid pond to create waves and droplet pops"
        }
    }

    public var accentColor: Color {
        switch self {
        case .corduroy: return Color(red: 0.85, green: 0.45, blue: 0.95)
        case .sand: return Color(red: 0.95, green: 0.8, blue: 0.4)
        case .magnetic: return Color(red: 0.25, green: 0.8, blue: 1.0)
        case .vinyl: return Color(red: 1.0, green: 0.4, blue: 0.4)
        case .water: return Color(red: 0.3, green: 0.9, blue: 0.8)
        }
    }

    public var shortcutNumber: String {
        switch self {
        case .corduroy: return "1"
        case .sand: return "2"
        case .magnetic: return "3"
        case .vinyl: return "4"
        case .water: return "5"
        }
    }
}
