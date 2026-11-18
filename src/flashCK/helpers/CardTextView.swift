import AppKit
import SwiftUI

/// Plain-text card field for inline editing in the Cards list. No scroll view: it grows with its text
/// so the list does all the scrolling. Tab / Shift+Tab move between fields, Return submits,
/// Option+Return inserts a newline, Esc cancels.
struct CardTextView: NSViewRepresentable {
    let text: String
    let isFocused: Bool
    let onChange: (String) -> Void
    let onFocusChange: (Bool) -> Void
    let onTab: (_ forward: Bool) -> Void
    let onSubmit: () -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> GrowingTextView {
        let view = GrowingTextView.make()
        view.delegate = context.coordinator
        view.string = text
        view.onFocusChange = { [weak coordinator = context.coordinator] in coordinator?.parent.onFocusChange($0) }
        return view
    }

    func updateNSView(_ view: GrowingTextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        if !view.hasMarkedText(), view.string != text {
            view.string = text
            coordinator.undo.removeAllActions()
            view.invalidateIntrinsicContentSize()
        }
        // Edge-triggered so a stale focus request never pulls focus back from another control.
        if isFocused, !coordinator.wasFocused { view.requestFocus() }
        coordinator.wasFocused = isFocused
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CardTextView
        var wasFocused = false
        /// Per-field undo, so Cmd+Z outside a field reaches the window (card delete undo).
        let undo = UndoManager()

        init(_ parent: CardTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            parent.onChange(view.string)
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertTab(_:)): parent.onTab(true)
            case #selector(NSResponder.insertBacktab(_:)): parent.onTab(false)
            case #selector(NSResponder.insertNewline(_:)): parent.onSubmit()
            case #selector(NSResponder.cancelOperation(_:)): parent.onCancel()
            default: return false
            }
            return true
        }

        func undoManager(for view: NSTextView) -> UndoManager? { undo }
    }
}

final class GrowingTextView: NSTextView {
    private static let minHeight: CGFloat = 28
    var onFocusChange: ((Bool) -> Void)?
    private var pendingFocus = false
    /// A hand-built TextKit 1 stack does not own its storage; the view keeps it alive.
    private var storage: NSTextStorage?

    static func make() -> GrowingTextView {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layout.addTextContainer(container)
        let view = GrowingTextView(frame: .zero, textContainer: container)
        view.storage = storage
        view.isRichText = false
        view.importsGraphics = false
        view.allowsUndo = true
        view.isVerticallyResizable = false
        view.isHorizontallyResizable = false
        view.focusRingType = .none
        view.font = .systemFont(ofSize: 13)
        view.textColor = NSColor(Color.textPrimary)
        view.insertionPointColor = NSColor(Color.textPrimary)
        view.backgroundColor = NSColor(Color.appBackground)
        view.drawsBackground = true
        view.textContainerInset = NSSize(width: 3, height: 5)
        view.setContentHuggingPriority(.defaultHigh, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        return view
    }

    /// Height of the laid-out text at the current width; SwiftUI supplies the width.
    override var intrinsicContentSize: NSSize {
        guard frame.width > 1, let layoutManager, let textContainer else {
            return NSSize(width: NSView.noIntrinsicMetric, height: Self.minHeight)
        }
        layoutManager.ensureLayout(for: textContainer)
        let height = layoutManager.usedRect(for: textContainer).height + textContainerInset.height * 2
        return NSSize(width: NSView.noIntrinsicMetric, height: max(ceil(height), Self.minHeight))
    }

    override func setFrameSize(_ newSize: NSSize) {
        let widthChanged = newSize.width != frame.width
        super.setFrameSize(newSize)
        if widthChanged { invalidateIntrinsicContentSize() }
    }

    override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
    }

    func requestFocus() {
        guard let window else {
            pendingFocus = true
            return
        }
        if window.firstResponder !== self { window.makeFirstResponder(self) }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard pendingFocus, let window else { return }
        pendingFocus = false
        window.makeFirstResponder(self)
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { reportFocus(true) }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted { reportFocus(false) }
        return accepted
    }

    /// Reported on the next main-actor turn: focus can change inside a SwiftUI update, where the model
    /// must not publish.
    private func reportFocus(_ focused: Bool) {
        let callback = onFocusChange
        Task { @MainActor in callback?(focused) }
    }
}
