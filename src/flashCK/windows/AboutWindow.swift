import AppKit
import SwiftUI

enum Links {
    static let repo = URL(string: "https://github.com/fosterbarnes/flashCK")!
    static let author = URL(string: "https://github.com/fosterbarnes")!
}

/// One reused About window. A plain NSWindow because `openWindow` and `Window` are macOS 13+.
@MainActor
enum AboutWindow {
    private static var window: NSWindow?

    static func show(model: AppModel) {
        let window = self.window ?? make(model: model)
        self.window = window
        window.makeKeyAndOrderFront(nil)
    }

    private static func make(model: AppModel) -> NSWindow {
        let host = NSHostingController(rootView: ThemedRoot(model: model) { AboutView() })
        let window = NSWindow(contentViewController: host)
        window.styleMask = [.titled, .closable]
        window.title = "About flashCK"
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(Color.appBackground)
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}

/// base MainWindow About layout: icon, name, version, repo link, app and data paths, credit line.
private struct AboutView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 128, height: 128)
            VStack(alignment: .leading, spacing: 0) {
                Text("flashCK").font(.system(size: 22, weight: .semibold))
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text("v\(version)").foregroundColor(.textSecondary).padding(.top, 2)
                }
                AboutLink(title: "github.com/fosterbarnes/flashCK", url: Links.repo)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                pathRow("App:", Bundle.main.bundleURL.path, help: "Show flashCK in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                }
                pathRow("Data:", model.paths.folder.path, help: "Open the data folder", action: openDataFolder)
                HStack(spacing: 0) {
                    Text("made with <3 by ").foregroundColor(.textSecondary)
                    AboutLink(title: "fosterbarnes", url: Links.author)
                }
                .font(.mono(14))
                .opacity(0.85)
                .padding(.top, 10)
            }
            Spacer(minLength: 0)
        }
        .panel()
        .padding(Metrics.pageMargin)
        .frame(width: 600)
        .background(Color.appBackground)
        .foregroundColor(.textPrimary)
    }

    private func pathRow(_ label: String, _ path: String, help: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label).font(.system(size: 13, weight: .semibold)).frame(width: 40, alignment: .leading)
            Text(path)
                .foregroundColor(.textSecondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(action: action) { Image(systemName: "folder").font(.system(size: 14)) }
                .buttonStyle(GhostButtonStyle())
                .help(help)
                .accessibilityLabel(help)
        }
        .padding(.top, 6)
    }

    /// The data folder appears on first save; create it so the button always opens something.
    private func openDataFolder() {
        do {
            try FileManager.default.createDirectory(at: model.paths.folder, withIntermediateDirectories: true)
            NSWorkspace.shared.open(model.paths.folder)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

private struct AboutLink: View {
    let title: String
    let url: URL
    @State private var hovering = false

    var body: some View {
        Button { NSWorkspace.shared.open(url) } label: {
            Text(title).underline(hovering).foregroundColor(.textPrimary)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(url.absoluteString)
        .accessibilityAddTraits(.isLink)
    }
}
