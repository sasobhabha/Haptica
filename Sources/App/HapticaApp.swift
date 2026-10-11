import SwiftUI
import AppKit

@main
struct HapticaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainContentView()
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandMenu("Textures") {
                ForEach(TextureType.allCases) { texture in
                    Button(texture.title) {
                        AppState.shared.setTexture(texture)
                    }
                    .keyboardShortcut(KeyEquivalent(Character(texture.shortcutNumber)), modifiers: [])
                }
            }

            CommandMenu("Haptics") {
                Button("Mute / Unmute Audio") {
                    AppState.shared.audio.isMuted.toggle()
                }
                .keyboardShortcut("m", modifiers: [.command])

                Button("Toggle Touch Overlay") {
                    AppState.shared.showTouchOverlay.toggle()
                }
                .keyboardShortcut("t", modifiers: [.command])

                Button("Toggle Always on Top") {
                    AppState.shared.isAlwaysOnTop.toggle()
                }
                .keyboardShortcut("p", modifiers: [.command])
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        if let window = NSApp.windows.first {
            window.title = "Haptica — Tactile Texture Lab"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.minSize = NSSize(width: 840, height: 580)
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
