import SwiftUI

/// Selection name (click it to rename in place; a pencil shows on hover). Empty while there is no subject to select or a new one is being named.
/// The All | star switch sits at the right while there are lessons to show.
struct Header: View {
    @EnvironmentObject private var model: AppModel
    /// Header title being renamed in place. Separate from `model.renaming`, the sidebar's field.
    @State private var renaming: RenameTarget?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let target = renameTarget, model.creating == nil {
                if renaming == target {
                    RenameField(initial: model.selectionName, font: Self.titleFont) {
                        renaming = nil
                        model.commitRename(target, to: $0)
                    } cancel: { renaming = nil }
                    .frame(maxWidth: 360)
                } else {
                    Button { renaming = target } label: {
                        Text(model.selectionName)
                            .font(Self.titleFont)
                            .lineLimit(1)
                    }
                    .buttonStyle(TitleButtonStyle())
                    .help(isLesson ? "Rename this lesson" : "Rename this subject")
                    .accessibilityLabel(isLesson ? "Rename lesson \(model.selectionName)" : "Rename subject \(model.selectionName)")
                }
            }
            Spacer(minLength: 0)
            if model.creating == nil, !model.library.lessons.isEmpty { StarFilterSwitch() }
        }
        .frame(height: Metrics.segmentHeight)
        // A new selection closes the field.
        .onChange(of: model.prefs.scope) { _ in renaming = nil }
    }

    private static let titleFont = Font.system(size: 20, weight: .semibold)

    private var renameTarget: RenameTarget? {
        switch model.prefs.scope {
        case .all: return nil
        case .subject(let id): return .subject(id)
        case .lesson(let id): return .lesson(id)
        }
    }

    private var isLesson: Bool { model.prefs.scope.lessonID != nil }
}

/// The header title as a rename button: a pencil to its right shows on hover or keyboard focus. The pencil
/// keeps its slot while hidden, so the hover area stays the same. No hover fill, like the sidebar trash.
private struct TitleButtonStyle: ButtonStyle {
    static let pencilSlot: CGFloat = 20

    func makeBody(configuration: Configuration) -> some View { Styled(configuration: configuration) }

    private struct Styled: View {
        let configuration: Configuration
        @Environment(\.palette) private var palette
        @Environment(\.isFocused) private var isFocused
        @State private var hovering = false

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                configuration.label
                    .foregroundColor(.textPrimary)
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(configuration.isPressed ? .textPrimary : .textMuted)
                    .frame(width: TitleButtonStyle.pencilSlot, alignment: .trailing)
                    .opacity(hovering || isFocused ? 1 : 0)
            }
            .padding(.horizontal, 2)
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.smallRadius)
                    .strokeBorder(isFocused ? palette.focus : .clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
        }
    }
}
