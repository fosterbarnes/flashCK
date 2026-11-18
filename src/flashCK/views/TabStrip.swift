import SwiftUI

struct TabItem<ID: Hashable>: Identifiable {
    let id: ID
    let title: String
}

/// base segment strip: equal-width tabs on controlAlt with a sliding accent indicator.
struct TabStrip<ID: Hashable>: View {
    let items: [TabItem<ID>]
    let selection: ID
    let select: (ID) -> Void
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width / CGFloat(max(items.count, 1))
            let index = items.firstIndex { $0.id == selection } ?? 0
            ZStack(alignment: .leading) {
                ForEach(1..<max(items.count, 1), id: \.self) { i in
                    Rectangle()
                        .fill(Color.borderSubtle)
                        .frame(width: 1)
                        .padding(.vertical, 4)
                        .offset(x: width * CGFloat(i))
                }
                RoundedRectangle(cornerRadius: Metrics.smallRadius)
                    .fill(palette.accentStrong)
                    .overlay(RoundedRectangle(cornerRadius: Metrics.smallRadius).strokeBorder(palette.accentBorder))
                    .frame(width: width)
                    .offset(x: width * CGFloat(index))
                    .animation(reduceMotion ? nil : .easeInOut(duration: Metrics.fadeDuration), value: index)
                HStack(spacing: 0) {
                    ForEach(items) { item in tab(item).frame(width: width) }
                }
            }
        }
        .frame(height: Metrics.segmentHeight)
        .background(Color.controlAlt)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.smallRadius))
    }

    private func tab(_ item: TabItem<ID>) -> some View {
        Button { select(item.id) } label: {
            Text(item.title)
                .font(.mono(13.5, weight: .semibold))
                .foregroundColor(item.id == selection ? .textPrimary : .textTertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
