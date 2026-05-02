import SwiftUI

@main
struct Jeff_AIApp: App {
    @StateObject private var chat = ChatViewModel()

    var body: some Scene {
        WindowGroup("Jeff AI") {
            ContentView()
                .environmentObject(chat)
                .frame(minWidth: 520, minHeight: 480)
        }
    }
}
