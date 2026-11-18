import AppKit
import SwiftUI
import flashCKCore

struct AppCommands: Commands {
    @ObservedObject var model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About flashCK") { AboutWindow.show(model: model) }
        }
        // Replacing .newItem also removes New Window.
        CommandGroup(replacing: .newItem) {
            Button("New Card") { model.addCard() }
                .keyboardShortcut("n")
                .disabled(!model.isReady || model.library.lessons.isEmpty)
            Button("New Subject") { model.beginNewSubject() }
                .keyboardShortcut("n", modifiers: [.command, .option])
                .disabled(!model.isReady)
            Button("New Lesson") { model.beginNewLesson() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(!model.isReady || model.library.subjects.isEmpty)
        }
        CommandMenu("Study") {
            Button("Cards") { model.setTab(.cards) }.keyboardShortcut("1").disabled(!model.isReady)
            Button("Study") { model.setTab(.study) }.keyboardShortcut("2").disabled(!model.isReady)
            Divider()
            Toggle("Shuffle", isOn: Binding(get: { model.prefs.shuffle }, set: { _ in model.toggleShuffle() }))
                .disabled(!model.isReady)
            Toggle("Back First", isOn: Binding(get: { model.prefs.backFirst }, set: { _ in model.toggleBackFirst() }))
                .disabled(!model.isReady)
        }
        CommandGroup(replacing: .help) {
            Button("flashCK on GitHub") { NSWorkspace.shared.open(Links.repo) }
        }
    }
}
