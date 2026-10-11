import SwiftUI

public struct SettingsBarView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var haptics = HapticEngine.shared
    @ObservedObject var audio = SoundSynthesizer.shared

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        HStack(spacing: 16) {
            // Haptic Strength Control
            HStack(spacing: 8) {
                Image(systemName: "hand.tap.fill")
                    .foregroundStyle(haptics.isEnabled ? .cyan : .secondary)
                    .font(.subheadline)

                Text("HAPTIC:")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .fixedSize()

                Slider(value: $haptics.intensity, in: 0.0...1.5, step: 0.1)
                    .frame(width: 80)
                    .tint(.cyan)

                Text(intensityLabel)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(intensityColor)
                    .frame(width: 42, alignment: .leading)
                    .lineLimit(1)
                    .fixedSize()
            }

            Divider().frame(height: 18).background(Color.white.opacity(0.15))

            // Audio Volume Control
            HStack(spacing: 8) {
                Button(action: { audio.isMuted.toggle() }) {
                    Image(systemName: audio.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .foregroundStyle(audio.isMuted ? .red : .white.opacity(0.8))
                        .font(.subheadline)
                }
                .buttonStyle(.plain)

                Slider(value: $audio.volume, in: 0.0...1.0, step: 0.05)
                    .frame(width: 70)
                    .tint(.white)
                    .disabled(audio.isMuted)
            }

            Divider().frame(height: 18).background(Color.white.opacity(0.15))

            // Texture Density Slider (for Corduroy ridges)
            if appState.selectedTexture == .corduroy {
                HStack(spacing: 8) {
                    Text("PITCH:")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                        .fixedSize()

                    Slider(value: $appState.ridgeSpacing, in: 14.0...48.0, step: 2.0)
                        .frame(width: 75)
                        .tint(.purple)
                }

                Divider().frame(height: 18).background(Color.white.opacity(0.15))
            }

            // Always on Top
            Button(action: { appState.isAlwaysOnTop.toggle() }) {
                HStack(spacing: 5) {
                    Image(systemName: appState.isAlwaysOnTop ? "pin.fill" : "pin")
                        .foregroundStyle(appState.isAlwaysOnTop ? .yellow : .white.opacity(0.6))
                    Text("Pin Top")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(appState.isAlwaysOnTop ? .yellow : .white.opacity(0.8))
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .buttonStyle(.plain)

            // Touch Visualizer toggle
            Button(action: { appState.showTouchOverlay.toggle() }) {
                HStack(spacing: 5) {
                    Image(systemName: appState.showTouchOverlay ? "eye.fill" : "eye.slash")
                        .foregroundStyle(appState.showTouchOverlay ? .cyan : .white.opacity(0.6))
                    Text("Touches")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(appState.showTouchOverlay ? .cyan : .white.opacity(0.8))
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Shortcuts hint
            Text("KEYS 1–5 SWITCH TEXTURES")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.08).opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        )
    }

    private var intensityLabel: String {
        if haptics.intensity < 0.1 {
            return "MUTE"
        } else if haptics.intensity < 0.8 {
            return "SOFT"
        } else if haptics.intensity <= 1.05 {
            return "NORM"
        } else {
            return "BOOST"
        }
    }

    private var intensityColor: Color {
        if haptics.intensity < 0.1 {
            return .red
        } else if haptics.intensity > 1.05 {
            return .orange
        } else {
            return .cyan
        }
    }
}
