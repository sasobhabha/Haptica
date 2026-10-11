import SwiftUI

public struct MainContentView: View {
    @StateObject private var appState = AppState.shared

    public init() {}

    public var body: some View {
        ZStack {
            // Main Window Dark Backdrop
            Color(red: 0.04, green: 0.05, blue: 0.07).ignoresSafeArea()

            VStack(spacing: 0) {
                // Main Tactile Texture Lab Stage
                ZStack {
                    TexturePlayground(appState: appState)

                    // Real-time Multi-Touch Overlay (Finger Halos & Rings)
                    if appState.showTouchOverlay {
                        TouchOverlayView(touches: appState.activeTouches)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom Settings & Status Bar
                SettingsBarView(appState: appState)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
        .frame(minWidth: 840, minHeight: 580)
        // Global Keyboard Shortcuts for Materials 1 to 5
        .background(
            VStack {
                Button("") { appState.setTexture(.corduroy) }.keyboardShortcut("1", modifiers: [])
                Button("") { appState.setTexture(.sand) }.keyboardShortcut("2", modifiers: [])
                Button("") { appState.setTexture(.magnetic) }.keyboardShortcut("3", modifiers: [])
                Button("") { appState.setTexture(.vinyl) }.keyboardShortcut("4", modifiers: [])
                Button("") { appState.setTexture(.water) }.keyboardShortcut("5", modifiers: [])
            }
            .opacity(0)
            .frame(width: 0, height: 0)
        )
    }
}
