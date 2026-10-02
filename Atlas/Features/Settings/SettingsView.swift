import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var heightCm: Double = 0
    @State private var weightKg: Double = 0
    @State private var birthYear: Double = 0
    @State private var fasting = false
    @State private var open = Date()
    @State private var close = Date()
    @State private var apiKey = ""
    @State private var confirmReset = false
    @State private var loaded = false
    @State private var showIntegrations = false

    var body: some View {
        NavigationStack {
            List {
                if app.profile != nil { profileSection }
                preferencesSection
                eatingSection
                intelligenceSection
                connectionsSection
                dataSection
                footer
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.bg)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitProfile()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("settingsDone")
                }
            }
            .navigationDestination(isPresented: $showIntegrations) { IntegrationsView() }
            .confirmationDialog("Erase all Atlas data?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Erase and start over", role: .destructive) {
                    dismiss()
                    app.resetAllData()
                }
            } message: {
                Text("Meals, workouts, sleep, memories and your plan are deleted from this device. Apple Health data is untouched.")
            }
            .onAppear(perform: load)
        }
    }

    private var units: UnitSystem { app.context.units }

    // MARK: Sections

    private var profileSection: some View {
        Section {
            row("Name") {
                TextField("Name", text: $name).multilineTextAlignment(.trailing).onSubmit(commitProfile)
            }
            row("Height") {
                if units == .imperial {
                    let totalIn = (heightCm / UnitConvert.cmPerInch).rounded()
                    HStack(spacing: Theme.Space.s) {
                        inlineNumber(Binding(get: { (totalIn / 12).rounded(.down) },
                                             set: { heightCm = ($0 * 12 + totalIn.truncatingRemainder(dividingBy: 12)) * UnitConvert.cmPerInch }),
                                     unit: "ft", decimals: 0)
                        inlineNumber(Binding(get: { totalIn.truncatingRemainder(dividingBy: 12) },
                                             set: { heightCm = ((totalIn / 12).rounded(.down) * 12 + min(11, max(0, $0))) * UnitConvert.cmPerInch }),
                                     unit: "in", decimals: 0)
                    }
                } else {
                    inlineNumber(Binding(get: { heightCm }, set: { heightCm = $0 }),
                                 unit: "cm", decimals: 0)
                }
            }
            row("Weight") {
                inlineNumber(Binding(get: { UnitConvert.weightDisplay(kg: weightKg, units: units) },
                                     set: { weightKg = UnitConvert.weightCanonical($0, units: units) }),
                             unit: UnitConvert.weightUnit(units), decimals: 1)
            }
            row("Birth year") {
                inlineNumber($birthYear, unit: "", decimals: 0, grouping: false)
            }
        } header: { header("Profile") }
    }

    private var preferencesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text("Units").textStyle(.body).foregroundStyle(Theme.Palette.textPrimary)
                Picker("Units", selection: Binding(get: { units }, set: { commitProfile(); app.setUnits($0) })) {
                    Text("Imperial (lb, in, mi)").tag(UnitSystem.imperial)
                    Text("Metric (kg, cm, km)").tag(UnitSystem.metric)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("unitsPicker")
            }
            .padding(.vertical, Theme.Space.xxs)
            .listRowBackground(Theme.Palette.surface)
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text("Coach tone").textStyle(.body).foregroundStyle(Theme.Palette.textPrimary)
                Picker("Coach tone", selection: Binding(get: { app.profile?.coachTone ?? .direct }, set: { app.setTone($0) })) {
                    ForEach(CoachTone.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, Theme.Space.xxs)
            .listRowBackground(Theme.Palette.surface)
        } header: { header("Preferences") }
    }

    private var eatingSection: some View {
        Section {
            Toggle("Time-restricted eating", isOn: $fasting)
                .textStyle(.body)
                .tint(Theme.Palette.accentFill)
                .listRowBackground(Theme.Palette.surface)
                .onChange(of: fasting) { _, _ in commitWindow() }
                .accessibilityIdentifier("settingsFasting")
            if fasting {
                DatePicker("Opens", selection: $open, displayedComponents: .hourAndMinute)
                    .listRowBackground(Theme.Palette.surface)
                    .onChange(of: open) { _, _ in commitWindow() }
                DatePicker("Closes", selection: $close, displayedComponents: .hourAndMinute)
                    .listRowBackground(Theme.Palette.surface)
                    .onChange(of: close) { _, _ in commitWindow() }
            }
        } header: { header("Eating window") } footer: {
            Text("Atlas times meals, protein and dinner reservations around your window.")
                .textStyle(.footnote)
        }
    }

    private var intelligenceSection: some View {
        Section {
            HStack {
                Text("Engine").textStyle(.body)
                Spacer()
                Text(app.engineStatus.name).textStyle(.body).foregroundStyle(Theme.Palette.textSecondary)
            }
            .listRowBackground(Theme.Palette.surface)
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                SecureField(app.remoteLLMConfigured ? "Key saved in Keychain" : "Optional OpenAI-compatible API key", text: $apiKey)
                    .textStyle(.body)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                HStack {
                    if app.remoteLLMConfigured {
                        Button("Remove key", role: .destructive) { app.setRemoteLLMKey(nil); apiKey = "" }
                            .buttonStyle(.borderless)
                    }
                    Spacer()
                    Button("Save key") { app.setRemoteLLMKey(apiKey); apiKey = "" }
                        .buttonStyle(.borderless)
                        .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .textStyle(.callout)
            }
            .listRowBackground(Theme.Palette.surface)
        } header: { header("Intelligence") } footer: {
            Text("Atlas runs fully on-device. Apple Intelligence is used when available; otherwise Atlas's built-in coach answers from your data. A key is never required.")
                .textStyle(.footnote)
        }
    }

    private var connectionsSection: some View {
        Section {
            Button {
                commitProfile()
                showIntegrations = true
            } label: {
                navRow("Integrations", symbol: "link")
            }
            .accessibilityIdentifier("integrationsRow")
            .listRowBackground(Theme.Palette.surface)
            Button {
                commitProfile()
                dismiss()
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    router.sheet = .memory
                }
            } label: {
                navRow("What Atlas remembers", symbol: "brain.head.profile")
            }
            .listRowBackground(Theme.Palette.surface)
        } header: { header("Connections") }
    }

    private var dataSection: some View {
        Section {
            Button {
                dismiss()
                app.loadSampleData()
            } label: {
                Text("Load sample data (Marcus)").textStyle(.body).foregroundStyle(Theme.Palette.textPrimary)
            }
            .listRowBackground(Theme.Palette.surface)
            Button(role: .destructive) {
                confirmReset = true
            } label: {
                Text("Erase all data").textStyle(.body).foregroundStyle(Theme.Palette.scoreLow)
            }
            .accessibilityIdentifier("eraseAll")
            .listRowBackground(Theme.Palette.surface)
        } header: { header("Data") }
    }

    private var footer: some View {
        Section {
            VStack(spacing: Theme.Space.xs) {
                AtlasMark(size: 28)
                Text("Atlas \(Bundle.main.shortVersion) (\(Bundle.main.buildNumber))")
                    .textStyle(.footnote)
                    .foregroundStyle(Theme.Palette.textTertiary)
                Text("Not medical advice. Check with a professional before big changes.")
                    .textStyle(.footnote)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }

    // MARK: Helpers

    private func header(_ text: String) -> some View {
        Text(text).textStyle(.micro).foregroundStyle(Theme.Palette.textSecondary)
    }

    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label).textStyle(.body).foregroundStyle(Theme.Palette.textPrimary)
            Spacer(minLength: Theme.Space.m)
            content().textStyle(.body).foregroundStyle(Theme.Palette.textSecondary)
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private func inlineNumber(_ value: Binding<Double>, unit: String, decimals: Int, grouping: Bool = true) -> some View {
        HStack(spacing: Theme.Space.xxs) {
            TextField("0", value: value, format: .number.precision(.fractionLength(0...decimals)).grouping(grouping ? .automatic : .never))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
                .onSubmit(commitProfile)
            if !unit.isEmpty { Text(unit).foregroundStyle(Theme.Palette.textTertiary) }
        }
    }

    private func navRow(_ title: String, symbol: String) -> some View {
        HStack(spacing: Theme.Space.s) {
            Image(systemName: symbol).icon(Theme.Icon.regular, weight: .regular).foregroundStyle(Theme.Palette.textSecondary).frame(width: Theme.Icon.large)
            Text(title).textStyle(.body).foregroundStyle(Theme.Palette.textPrimary)
            Spacer()
            Image(systemName: "chevron.right").icon(Theme.Icon.small).foregroundStyle(Theme.Palette.textTertiary)
        }
        .contentShape(.rect)
    }

    private func load() {
        guard !loaded, let p = app.profile else { return }
        name = p.name
        heightCm = p.heightCm
        weightKg = p.weightKg
        birthYear = Double(p.birthYear)
        let day = AppClock.now
        fasting = p.fastingStartMinutes != nil
        open = UnitConvert.minutesToTime(p.fastingStartMinutes ?? 12 * 60, on: day)
        close = UnitConvert.minutesToTime(p.fastingEndMinutes ?? 20 * 60, on: day)
        loaded = true
    }

    private func commitProfile() {
        guard loaded, let p = app.profile else { return }
        let changed = p.name != name || p.heightCm != heightCm || p.weightKg != weightKg || p.birthYear != Int(birthYear)
        guard changed else { return }
        p.name = name
        if heightCm > 100 { p.heightCm = heightCm }
        if weightKg > 30 { p.weightKg = weightKg }
        if birthYear > 1900 { p.birthYear = Int(birthYear) }
        app.saveProfile()
    }

    private func commitWindow() {
        guard loaded else { return }
        if fasting {
            app.setEatingWindow(open: UnitConvert.timeToMinutes(open), close: UnitConvert.timeToMinutes(close))
        } else {
            app.setEatingWindow(open: nil, close: nil)
        }
    }
}

extension Bundle {
    var shortVersion: String { object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0" }
    var buildNumber: String { object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1" }
}
