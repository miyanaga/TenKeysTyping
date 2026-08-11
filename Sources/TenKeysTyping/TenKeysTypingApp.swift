import AppKit
import SwiftUI

@main
struct TenKeysTypingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var history = HistoryStore()
    @StateObject private var sound: SoundEngine
    @StateObject private var engine: GameEngine

    init() {
        let soundEngine = SoundEngine()
        _sound = StateObject(wrappedValue: soundEngine)
        _engine = StateObject(wrappedValue: GameEngine(sound: soundEngine))
    }

    var body: some Scene {
        WindowGroup("TenKeysTyping") {
            RootView(engine: engine)
                .environmentObject(history)
                .environmentObject(sound)
                .frame(minWidth: 900, minHeight: 680)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 980, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
