# Haptica 🎛️

> Turn your Mac trackpad into a tactile haptic playground.

Haptica uses macOS low-level hardware actuator interfaces (`MultitouchSupport` / `NSHapticFeedbackManager`) alongside real-time procedural acoustics (`AVAudioEngine`) to simulate rich physical materials directly under your fingertips on Apple Force Touch trackpads.

![Haptica Screenshot](/tmp/haptica_texture_lab.png)

## ✨ Tactile Materials

- **Corduroy & Washboard [1]**: Corrugated ribbed ridges. Sliding your finger across produces speed-sensitive micro-clicks with glowing ridge highlights. Includes adjustable ridge pitch/density!
- **Sand & Quartz Grit [2]**: Granular particles that swirl and scatter under your finger trail with stochastic micro-haptic crunches.
- **Magnetic Grid [3]**: 2D grid of attractor nodes with elastic snap beams and tactile detents.
- **Vinyl Scratch [4]**: 33 RPM turntable record that you can scratch back and forth with grooved friction ticks and needle inertia.
- **Water Ripples [5]**: Fluid pond where moving creates expanding wave rings and soft droplet haptic pulses.

## 🚀 Building & Running

### Prerequisites
- macOS 13+ (Ventura, Sonoma, Sequoia)
- A Mac with a Force Touch trackpad (MacBook Pro, MacBook Air) or external Magic Trackpad
- Xcode 15+ / Swift 5.9+

### Build & Run
```bash
# Clone the repository
git clone https://github.com/shashwath/Haptica.git
cd Haptica

# Run directly
swift run

# Or build release .app
swift build -c release
```

## ⌨️ Controls & Shortcuts
- `1` - `5`: Switch between textures
- `Cmd + M`: Mute/unmute procedural sound
- `Cmd + T`: Toggle multi-touch overlay
- `Cmd + P`: Toggle Always-on-Top pin

## 📄 License
MIT License.
