import SwiftUI

/// Coach message: editorial text, no bubble, small Atlas avatar.
struct CoachMessageView<Accessory: View>: View {
    let text: String
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.s) {
            CoachAvatar()
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Text(LocalizedStringKey(text))
                    .textStyle(.body)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                accessory()
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
    }
}

extension CoachMessageView where Accessory == EmptyView {
    init(text: String) {
        self.init(text: text) { EmptyView() }
    }
}

/// User message: right-aligned elevated bubble.
struct UserBubble: View {
    let text: String

    var body: some View {
        HStack {
            Spacer(minLength: Theme.Space.huge)
            Text(text)
                .textStyle(.body)
                .foregroundStyle(Theme.Palette.textPrimary)
                .padding(.horizontal, Theme.Space.m)
                .padding(.vertical, Theme.Space.s)
                .background(Theme.Palette.fillStrong, in: .rect(cornerRadius: 20, style: .continuous))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Three pulsing dots.
struct TypingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Space.s) {
            CoachAvatar()
            TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        let phase = reduceMotion ? 1 : (sin(t * 5 - Double(i) * 0.8) + 1) / 2
                        Circle()
                            .fill(Theme.Palette.textSecondary)
                            .frame(width: 7, height: 7)
                            .opacity(0.3 + 0.7 * phase)
                            .scaleEffect(0.8 + 0.25 * phase)
                    }
                }
            }
            Spacer()
        }
        .accessibilityLabel("Atlas is thinking")
    }
}

/// Horizontally scrolling suggestion chips.
struct SuggestionChips: View {
    let suggestions: [String]
    let onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.xs) {
                ForEach(suggestions, id: \.self) { s in
                    Button(s) { onTap(s) }
                        .buttonStyle(.atlasChip)
                }
            }
            .padding(.horizontal, Theme.Space.gutter)
        }
        .scrollClipDisabled()
    }
}

/// Floating capsule composer (glass on iOS 26, material fallback).
struct Composer: View {
    @Binding var text: String
    var placeholder: String = "Ask Atlas anything"
    var isBusy = false
    var focus: FocusState<Bool>.Binding
    let onSend: () -> Void

    private var canSend: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isBusy }

    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Space.xs) {
            TextField(placeholder, text: $text, axis: .vertical)
                .textStyle(.body)
                .foregroundStyle(Theme.Palette.textPrimary)
                .lineLimit(1...5)
                .focused(focus)
                .submitLabel(.send)
                .onSubmit { if canSend { onSend() } }
                .padding(.vertical, 10)
                .padding(.leading, Theme.Space.m)
                .accessibilityLabel("Message Atlas")
            Button(action: onSend) {
                Image(systemName: canSend ? "arrow.up" : "waveform")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(canSend ? Theme.Palette.onPrimary : Theme.Palette.textSecondary)
                    .frame(width: Theme.Size.iconButton, height: Theme.Size.iconButton)
                    .background(canSend ? Theme.Palette.textPrimary : Theme.Palette.fill, in: .circle)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .padding(4)
            .animation(Theme.Motion.snappy, value: canSend)
            .accessibilityLabel("Send")
        }
        .modifier(GlassCapsule())
    }
}

/// Liquid Glass on iOS 26, ultra-thin material elsewhere.
struct GlassCapsule: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: Theme.Radius.card, style: .continuous))
        } else {
            content
                .background(.ultraThinMaterial, in: .rect(cornerRadius: Theme.Radius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).strokeBorder(Theme.Palette.hairline, lineWidth: Theme.Stroke.hairline))
        }
    }
}
