import AppKit
import SwiftUI

/// A local key-down monitor for the main window, because `onKeyPress` is macOS 14+ and button key
/// equivalents fire inside text fields. Installed only while the view is on screen. The handler returns
/// true when it used the key. Keys pass through with Cmd/Ctrl/Option, for other windows (alerts, Settings),
/// while a sheet is up, and while typing in a text field.
private struct MainWindowKeys: ViewModifier {
    let model: AppModel
    let handle: @MainActor (NSEvent) -> Bool
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard monitor == nil else { return }
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak model, handle] event in
                    let handled = MainActor.assumeIsolated { () -> Bool in
                        guard let model, Self.accepts(event, model: model) else { return false }
                        return handle(event)
                    }
                    return handled ? nil : event
                }
            }
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
            }
    }

    @MainActor
    private static func accepts(_ event: NSEvent, model: AppModel) -> Bool {
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
              let window = event.window, window === model.mainWindow, window.attachedSheet == nil else { return false }
        return !(window.firstResponder is NSText)
    }
}

enum KeyCode {
    static let space: UInt16 = 49
    static let escape: UInt16 = 53
    static let returnKey: UInt16 = 36
    /// Keypad Enter.
    static let enter: UInt16 = 76
    static let left: UInt16 = 123
    static let right: UInt16 = 124
    /// Backspace, labelled "delete" on Mac keyboards.
    static let delete: UInt16 = 51
    /// Forward delete (fn+delete, or Delete on a PC keyboard).
    static let forwardDelete: UInt16 = 117
}

extension View {
    func mainWindowKeys(_ model: AppModel, handle: @escaping @MainActor (NSEvent) -> Bool) -> some View {
        modifier(MainWindowKeys(model: model, handle: handle))
    }

    /// Space flips; Left/Right are previous/next in Cards. With Keyboard navigation on, Space presses the
    /// focused control instead (Study focuses Flip, so it still flips until the user tabs away).
    func studyKeys(_ model: AppModel) -> some View {
        mainWindowKeys(model) { [weak model] event in
            guard let model else { return false }
            switch event.keyCode {
            case KeyCode.space:
                if NSApp.isFullKeyboardAccessEnabled { return false }
                if !event.isARepeat { model.flip() }
            case KeyCode.left: model.studyArrow(right: false)
            case KeyCode.right: model.studyArrow(right: true)
            default: return false
            }
            return true
        }
    }
}
