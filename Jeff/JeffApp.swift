import SwiftUI

@main
struct JeffApp: App {
    @StateObject private var coordinator = PipelineCoordinator()

    var body: some Scene {
        WindowGroup("Jeff") {
            ContentView()
                .environmentObject(coordinator)
                .environmentObject(coordinator.store)
                .environmentObject(coordinator.settingsStore)
                .frame(minWidth: 520, minHeight: 420)
                .task { await coordinator.start() }
                .onDisappear { coordinator.stop() }
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(coordinator.settingsStore)
        }
    }
}
