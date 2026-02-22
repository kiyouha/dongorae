import SwiftUI

enum AppPalette {
    static let green = Color(red: 0.396, green: 0.749, blue: 0.619)
    static let yellow = Color(red: 0.84, green: 0.66, blue: 0.20)
    static let red = Color.red
    static let blue = Color.blue
}

enum AppTypography {
    static let title = Font.body.weight(.semibold)
    static let body = Font.body
}

enum AppSpacing {
    static let pageHorizontal: CGFloat = 16
    static let sectionVertical: CGFloat = 10
    static let rowVertical: CGFloat = 10
}

struct AppCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppTypography.body.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sectionVertical + 2)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct AppSummaryChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
            Text(value)
                .font(AppTypography.body.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sectionVertical)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct AppBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(AppTypography.body.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.16)))
    }
}

private struct MarqueeWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct AutoMarqueeText: View {
    let text: String
    let font: Font
    let color: Color
    let alignment: Alignment
    let gap: CGFloat
    let speed: CGFloat

    @State private var textWidth: CGFloat = .zero
    @State private var containerWidth: CGFloat = .zero
    @State private var animate = false

    init(
        _ text: String,
        font: Font = .caption,
        color: Color = .primary,
        alignment: Alignment = .leading,
        gap: CGFloat = 28,
        speed: CGFloat = 28
    ) {
        self.text = text
        self.font = font
        self.color = color
        self.alignment = alignment
        self.gap = gap
        self.speed = speed
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: alignment) {
                if shouldScroll(for: width) {
                    HStack(spacing: gap) {
                        marqueeText
                        marqueeText
                    }
                    .offset(x: animate ? -(textWidth + gap) : 0)
                    .onAppear { startAnimation() }
                } else {
                    marqueeText
                        .frame(maxWidth: .infinity, alignment: alignment == .trailing ? .trailing : .leading)
                }
            }
            .clipped()
            .background(
                Text(text)
                    .font(font)
                    .lineLimit(1)
                    .fixedSize()
                    .hidden()
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: MarqueeWidthKey.self, value: geo.size.width)
                        }
                    )
            )
            .onPreferenceChange(MarqueeWidthKey.self) { textWidth = $0 }
            .onAppear { containerWidth = width }
            .onChange(of: width) { _, newValue in containerWidth = newValue }
        }
        .frame(height: 18)
    }

    private var marqueeText: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func shouldScroll(for width: CGFloat) -> Bool {
        textWidth > width && !text.isEmpty
    }

    private func startAnimation() {
        guard shouldScroll(for: containerWidth), !animate else { return }
        let duration = max((textWidth + gap) / speed, 2.8)
        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            animate = true
        }
    }
}

struct AutoMarqueeAttributedText: View {
    let text: AttributedString
    let alignment: Alignment
    let gap: CGFloat
    let speed: CGFloat

    @State private var textWidth: CGFloat = .zero
    @State private var containerWidth: CGFloat = .zero
    @State private var animate = false

    init(
        _ text: AttributedString,
        alignment: Alignment = .leading,
        gap: CGFloat = 28,
        speed: CGFloat = 28
    ) {
        self.text = text
        self.alignment = alignment
        self.gap = gap
        self.speed = speed
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: alignment) {
                if shouldScroll(for: width) {
                    HStack(spacing: gap) {
                        marqueeText
                        marqueeText
                    }
                    .offset(x: animate ? -(textWidth + gap) : 0)
                    .onAppear { startAnimation() }
                } else {
                    marqueeText
                        .frame(maxWidth: .infinity, alignment: alignment == .trailing ? .trailing : .leading)
                }
            }
            .clipped()
            .background(
                Text(text)
                    .lineLimit(1)
                    .fixedSize()
                    .hidden()
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: MarqueeWidthKey.self, value: geo.size.width)
                        }
                    )
            )
            .onPreferenceChange(MarqueeWidthKey.self) { textWidth = $0 }
            .onAppear { containerWidth = width }
            .onChange(of: width) { _, newValue in containerWidth = newValue }
        }
        .frame(height: 18)
    }

    private var marqueeText: some View {
        Text(text)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func shouldScroll(for width: CGFloat) -> Bool {
        textWidth > width && !String(text.characters).isEmpty
    }

    private func startAnimation() {
        guard shouldScroll(for: containerWidth), !animate else { return }
        let duration = max((textWidth + gap) / speed, 2.8)
        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            animate = true
        }
    }
}
