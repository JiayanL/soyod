import SwiftUI
import SwiftData

/// "What Atlas remembers": facts / preferences / tasks with edit, delete and add.
struct MemorySheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MemoryItem.createdAt, order: .reverse) private var items: [MemoryItem]

    @State private var newText = ""
    @State private var newKind: MemoryKind = .fact
    @State private var editing: MemoryItem?
    @State private var editText = ""
    @FocusState private var addFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Atlas uses these to personalize plans, restaurant picks and swaps. Edit or delete anything.")
                        .textStyle(.callout)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: Theme.Space.xxs, bottom: Theme.Space.xs, trailing: Theme.Space.xxs))
                }
                if items.isEmpty {
                    Section {
                        EmptyStateView(symbol: "brain.head.profile", title: "Nothing yet", message: "Tell Atlas things like \"remember my knee is sore\" and they'll show up here.")
                            .listRowBackground(Color.clear)
                    }
                }
                ForEach(MemoryKind.allCases, id: \.self) { kind in
                    let group = items.filter { $0.kind == kind }
                    if !group.isEmpty {
                        Section {
                            ForEach(group) { item in
                                MemoryRow(item: item) {
                                    item.isDone.toggle()
                                    app.updateMemory(item)
                                }
                                .contentShape(.rect)
                                .onTapGesture {
                                    editText = item.text
                                    editing = item
                                }
                                .listRowBackground(Theme.Palette.surface)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        withAnimation { app.deleteMemory(item) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            Text(kind.title)
                                .textStyle(.micro)
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }
                }
                Section {
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        Picker("Type", selection: $newKind) {
                            ForEach(MemoryKind.allCases, id: \.self) { k in
                                Text(k.singular).tag(k)
                            }
                        }
                        .pickerStyle(.segmented)
                        HStack(spacing: Theme.Space.xs) {
                            TextField("Add something Atlas should know", text: $newText, axis: .vertical)
                                .textStyle(.body)
                                .focused($addFocused)
                                .accessibilityIdentifier("memoryInput")
                            Button("Add", action: add)
                                .buttonStyle(.atlasPrimaryCompact)
                                .disabled(newText.trimmingCharacters(in: .whitespaces).isEmpty)
                                .accessibilityIdentifier("memoryAdd")
                        }
                    }
                    .padding(.vertical, Theme.Space.xxs)
                    .listRowBackground(Theme.Palette.surface)
                } header: {
                    Text("Add memory").textStyle(.micro).foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.bg)
            .navigationTitle("What Atlas remembers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .alert("Edit memory", isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
                TextField("Memory", text: $editText)
                Button("Save") {
                    if let editing, !editText.trimmingCharacters(in: .whitespaces).isEmpty {
                        editing.text = editText
                        app.updateMemory(editing)
                    }
                    editing = nil
                }
                Button("Delete", role: .destructive) {
                    if let editing { app.deleteMemory(editing) }
                    editing = nil
                }
                Button("Cancel", role: .cancel) { editing = nil }
            }
        }
        .sensoryFeedback(.success, trigger: items.count)
    }

    private func add() {
        let t = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        app.addMemory(kind: newKind, text: t, dueDate: nil)
        newText = ""
        addFocused = false
    }
}

private struct MemoryRow: View {
    let item: MemoryItem
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.s) {
            if item.kind == .task {
                Button(action: onToggle) {
                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                        .icon(Theme.Icon.large, weight: .regular)
                        .foregroundStyle(item.isDone ? Theme.Palette.recovery : Theme.Palette.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.isDone ? "Mark not done" : "Mark done")
            } else {
                Image(systemName: item.kind.symbol)
                    .icon(Theme.Icon.small)
                    .foregroundStyle(item.kind.color)
                    .frame(width: Theme.Icon.large, height: Theme.Icon.large)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.text)
                    .textStyle(.body)
                    .foregroundStyle(item.isDone ? Theme.Palette.textTertiary : Theme.Palette.textPrimary)
                    .strikethrough(item.isDone)
                    .fixedSize(horizontal: false, vertical: true)
                if let due = item.dueDate {
                    Text("Due \(Fmt.relativeDay(due)) · \(due.formatted(.dateTime.month(.abbreviated).day()))")
                        .textStyle(.footnote)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
        }
        .padding(.vertical, Theme.Space.xxs)
    }
}

extension MemoryKind {
    var singular: String {
        switch self {
        case .fact: "Fact"
        case .preference: "Preference"
        case .task: "Task"
        }
    }

    var symbol: String {
        switch self {
        case .fact: "info.circle.fill"
        case .preference: "heart.fill"
        case .task: "checkmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .fact: Theme.Palette.sleep
        case .preference: Theme.Palette.train
        case .task: Theme.Palette.accent
        }
    }
}
