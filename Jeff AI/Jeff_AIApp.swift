import SwiftUI

@main
struct Jeff_AIApp: App {
    @StateObject private var settings: SettingsStore
    @StateObject private var models: ModelsStore
    @StateObject private var chat: ChatViewModel

    init() {
        let s = SettingsStore()
        let m = ModelsStore(settings: s)
        let c = ChatViewModel()
        c.attach(settings: s, models: m)
        _settings = StateObject(wrappedValue: s)
        _models = StateObject(wrappedValue: m)
        _chat = StateObject(wrappedValue: c)
    }

    var body: some Scene {
        WindowGroup("Jeff AI") {
            ContentView()
                .environmentObject(chat)
                .environmentObject(settings)
                .environmentObject(models)
                .frame(minWidth: 520, minHeight: 480)
        }
        .commands {
            CommandMenu("Settings") {
                SettingsLink {
                    Text("Open Settings…")
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(models)
        }
    }
}
