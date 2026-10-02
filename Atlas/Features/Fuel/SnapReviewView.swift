import SwiftUI

/// Photo → recognized items → edit → log (Cal AI-style review).
struct SnapReviewView: View {
    let image: UIImage
    var sampleName: String? = nil

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase: Phase = .analyzing
    @State private var items: [FoodItem] = []
    @State private var mealType: MealType = AppState.defaultMealType(at: AppClock.now)
    @State private var fixing = false
    @State private var fixText = ""
    @State private var usedFallback = false
    @State private var saved = false
    @State private var scan: CGFloat = 0

    enum Phase { case analyzing, ready, empty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    photo
                    content
                }
                .padding(.bottom, Theme.Space.xxxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .atlasScreenBackground()
            .ignoresSafeArea(edges: .top)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    IconButton(symbol: "xmark", label: "Cancel") { dismiss() }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                if phase != .analyzing {
                    VStack(spacing: Theme.Space.s) {
                        if !items.isEmpty { MacroTotalsRow(items: items) }
                        HStack(spacing: Theme.Space.s) {
                            Button {
                                withAnimation(Theme.Motion.standard) { fixing.toggle() }
                            } label: {
                                Label("Fix results", systemImage: "wand.and.stars")
                            }
                            .buttonStyle(SecondaryButtonStyle(fullWidth: true))
                            .accessibilityIdentifier("fixResults")
                            Button("Log meal", action: save)
                                .buttonStyle(.atlasPrimary)
                                .disabled(items.isEmpty)
                                .accessibilityIdentifier("snapLogMeal")
                        }
                    }
                    .gutter()
                    .padding(.vertical, Theme.Space.s)
                    .bottomBarScrim()
                }
            }
            .task { await analyze() }
            .sensoryFeedback(.success, trigger: saved)
        }
    }

    // MARK: Photo

    private var photo: some View {
        Color.clear
            .containerRelativeFrame(.vertical) { h, _ in min(340, h * 0.34) }
            .overlay {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
            .overlay(alignment: .top) {
                if phase == .analyzing && !reduceMotion {
                    GeometryReader { g in
                        LinearGradient(colors: [.clear, Theme.Palette.accentFill.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 90)
                            .offset(y: scan * (g.size.height - 40) - 45)
                            .blendMode(.plusLighter)
                    }
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { scan = 1 }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.clear, Theme.Palette.bg], startPoint: .center, endPoint: .bottom)
            }
            .overlay { if phase == .ready { floatingLabels } }
            .accessibilityHidden(true)
    }

    private var floatingLabels: some View {
        GeometryReader { proxy in
            let spots: [CGPoint] = [CGPoint(x: 0.3, y: 0.38), CGPoint(x: 0.68, y: 0.3), CGPoint(x: 0.6, y: 0.6), CGPoint(x: 0.28, y: 0.66), CGPoint(x: 0.5, y: 0.45)]
            ForEach(Array(items.prefix(5).enumerated()), id: \.element.id) { i, item in
                let p = spots[i % spots.count]
                HStack(spacing: Theme.Space.xxs) {
                    Text(item.emoji ?? "🍽️")
                    Text(item.name).lineLimit(1)
                    Text("\(Int(item.kcal.rounded()))").foregroundStyle(Theme.Palette.textSecondary)
                }
                .textStyle(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Palette.textPrimary)
                .padding(.horizontal, Theme.Space.s)
                .padding(.vertical, Theme.Space.xxs + 2)
                .background(.ultraThinMaterial, in: .capsule)
                .fixedSize()
                .position(x: proxy.size.width * p.x, y: (proxy.size.height + 60) * p.y)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            switch phase {
            case .analyzing:
                HStack(spacing: Theme.Space.s) {
                    ProgressView()
                    Text("Identifying what's on your plate…")
                        .textStyle(.headline)
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
                .padding(.top, Theme.Space.l)
            case .empty:
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text("Couldn't read this one")
                        .textStyle(.displayS)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("Describe it in a few words and Atlas will estimate it.")
                        .textStyle(.body)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                fixField
            case .ready:
                VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                    MicroLabel(usedFallback ? "Matched on-device" : "Recognized on-device", color: Theme.Palette.accent)
                    Text(MealNaming.title(for: items))
                        .textStyle(.displayS)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if fixing { fixField.transition(.opacity) }
                FoodItemsEditor(items: $items, showsConfidence: false)
                    .atlasCard()
                    .padding(.bottom, Theme.Space.m)
                FormGroup(title: "Meal") { MealTypePicker(selection: $mealType) }
            }
        }
        .gutter()
        .animation(Theme.Motion.standard, value: items)
        .animation(Theme.Motion.standard, value: phase)
    }

    private var fixField: some View {
        HStack(spacing: Theme.Space.xs) {
            TextField("Add or correct: \"no rice, add 1 avocado\"", text: $fixText, axis: .vertical)
                .textStyle(.body)
                .lineLimit(1...3)
                .onSubmit(applyFix)
                .accessibilityIdentifier("fixField")
            Button("Add", action: applyFix)
                .buttonStyle(.atlasPrimaryCompact)
                .disabled(fixText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(Theme.Space.s)
        .background(Theme.Palette.fill, in: .rect(cornerRadius: Theme.Radius.inner, style: .continuous))
    }

    private func applyFix() {
        let lower = fixText.lowercased()
        for token in lower.components(separatedBy: CharacterSet(charactersIn: ",;")) {
            let t = token.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("no ") || t.hasPrefix("remove ") || t.hasPrefix("without ") {
                let word = t.split(separator: " ").dropFirst().joined(separator: " ")
                items.removeAll { $0.name.lowercased().contains(word) }
            }
        }
        let added = FoodTextParser.parse(fixText.replacingOccurrences(of: "add ", with: "", options: .caseInsensitive))
            .filter { item in !lower.contains("no \(item.name.lowercased())") }
        items.append(contentsOf: added)
        fixText = ""
        if !items.isEmpty { phase = .ready }
        hideKeyboard()
    }

    private func analyze() async {
        let result = await FoodRecognizer.recognize(image, hint: sampleName)
        usedFallback = result.usedFallback
        withAnimation(Theme.Motion.standard) {
            items = result.items
            phase = result.items.isEmpty ? .empty : .ready
        }
    }

    private func save() {
        let data = image.preparingThumbnail(of: CGSize(width: 600, height: 600 * image.size.height / max(1, image.size.width)))?.jpegData(compressionQuality: 0.8)
            ?? image.jpegData(compressionQuality: 0.7)
        app.logMeal(title: MealNaming.title(for: items), mealType: mealType, items: items, photo: data, source: .photo, date: AppClock.now)
        saved = true
        dismiss()
    }
}
