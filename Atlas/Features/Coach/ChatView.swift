import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @Query(sort: \CoachMessage.date) private var messages: [CoachMessage]
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Space.l) {
                    if messages.isEmpty {
                        ChatIntro()
                    }
                    ForEach(messages) { message in
                        MessageRow(message: message)
                            .id(message.id)
                    }
                    if app.isCoachThinking {
                        TypingIndicator()
                            .id("typing")
                            .transition(.opacity)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .gutter()
                .padding(.top, Theme.Space.m)
                .padding(.bottom, Theme.Space.m)
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .onChange(of: messages.count) { _, _ in
                withAnimation(Theme.Motion.standard) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: app.isCoachThinking) { _, _ in
                withAnimation(Theme.Motion.standard) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
        .atlasScreenBackground()
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Theme.Space.s) {
                if !focused || text.isEmpty {
                    SuggestionChips(suggestions: app.suggestedPrompts) { send($0) }
                }
                Composer(text: $text, isBusy: app.isCoachThinking, focus: $focused) { send(text) }
                    .accessibilityIdentifier("composer")
                    .gutter()
            }
            .padding(.top, Theme.Space.xs)
            .padding(.bottom, Theme.Space.xs)
            .bottomBarScrim()
        }
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(Theme.Palette.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text("Atlas").textStyle(.headline).foregroundStyle(Theme.Palette.textPrimary)
                    Text((app.lastReplyEngine ?? app.engineStatus).name)
                        .textStyle(.micro)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
                .accessibilityElement(children: .combine)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.sheet = .memory
                } label: {
                    Image(systemName: "brain.head.profile").icon(Theme.Icon.regular)
                }
                .accessibilityLabel("What Atlas remembers")
                .accessibilityIdentifier("memoryButton")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: consumePrefill)
        .onChange(of: router.chatPrefill) { _, _ in consumePrefill() }
    }

    private func consumePrefill() {
        guard let prefill = router.chatPrefill else { return }
        router.chatPrefill = nil
        if router.chatAutoSend {
            router.chatAutoSend = false
            send(prefill)
        } else {
            text = prefill
            focused = true
        }
    }

    private func send(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !app.isCoachThinking else { return }
        text = ""
        Task { await app.send(trimmed) }
    }
}

private struct MessageRow: View {
    let message: CoachMessage

    var body: some View {
        switch message.role {
        case .user:
            UserBubble(text: message.text)
        case .coach:
            let actions = message.actions.filter { $0.status != .dismissed }
            CoachMessageView(text: message.text) {
                if !actions.isEmpty {
                    VStack(spacing: Theme.Space.s) {
                        ForEach(actions) { action in
                            CoachActionCard(action: action, messageID: message.id)
                        }
                    }
                    .padding(.top, Theme.Space.xxs)
                }
            }
        }
    }
}

private struct ChatIntro: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            AtlasMark(size: 40, glow: true)
            Text("What's on today?")
                .textStyle(.displayS)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("Tell me about dinners, bad nights, cravings or a missed session. I'll adjust the plan, and I can book, order, schedule and remind.")
                .textStyle(.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Theme.Space.xl)
    }
}
