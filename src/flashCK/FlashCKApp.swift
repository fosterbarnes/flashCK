import SwiftUI

@main
struct FlashCKApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            ThemedRoot(model: delegate.model) { MainView() }
        }
        .commands { AppCommands(model: delegate.model) }
        Settings {
            ThemedRoot(model: delegate.model) { SettingsView() }
        }
    }
}

/// Hands every window the model and the current palette, so a Theme switch repaints at once.
struct ThemedRoot<Content: View>: View {
    @ObservedObject var model: AppModel
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .environmentObject(model)
            .environment(\.palette, model.palette)
    }
}
