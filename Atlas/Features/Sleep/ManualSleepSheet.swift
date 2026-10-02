import SwiftUI

struct ManualSleepSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var bed: Date
    @State private var wake: Date
    @State private var quality = 3

    init() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: AppClock.now)
        _wake = State(initialValue: cal.date(byAdding: .hour, value: 7, to: today) ?? AppClock.now)
        _bed = State(initialValue: cal.date(byAdding: .minute, value: -30, to: today) ?? AppClock.now)
    }

    private var minutes: Int { max(0, Int(wake.timeIntervalSince(bed) / 60)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                        MicroLabel("Time asleep", color: Theme.Palette.sleep)
                        Text(Fmt.duration(minutes: minutes))
                            .textStyle(.metricXL)
                            .foregroundStyle(minutes > 0 ? Theme.Palette.textPrimary : Theme.Palette.scoreLow)
                            .contentTransition(.numericText())
                    }
                    VStack(spacing: 0) {
                        DatePicker("Went to bed", selection: $bed, in: ...AppClock.now)
                            .padding(.vertical, Theme.Space.xs)
                        Hairline()
                        DatePicker("Woke up", selection: $wake, in: bed...AppClock.now.addingTimeInterval(3600))
                            .padding(.vertical, Theme.Space.xs)
                    }
                    .textStyle(.body)
                    .atlasCard()
                    FormGroup(title: "How did you feel?") {
                        HStack(spacing: Theme.Space.xs) {
                            ForEach(1...5, id: \.self) { q in
                                Button {
                                    quality = q
                                } label: {
                                    VStack(spacing: Theme.Space.xxs) {
                                        Image(systemName: symbol(q)).icon(Theme.Icon.large, weight: .regular)
                                        Text(word(q)).textStyle(.micro)
                                    }
                                    .foregroundStyle(quality == q ? Theme.Palette.onPrimary : Theme.Palette.textPrimary)
                                    .frame(maxWidth: .infinity, minHeight: 64)
                                    .background(quality == q ? Theme.Palette.sleep : Theme.Palette.fill, in: .rect(cornerRadius: Theme.Radius.small, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(word(q))
                                .accessibilityAddTraits(quality == q ? .isSelected : [])
                            }
                        }
                    }
                    Text("Manual nights get an estimated stage breakdown so your scores stay comparable.")
                        .textStyle(.footnote)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
                .gutter()
                .padding(.top, Theme.Space.m)
            }
            .atlasScreenBackground()
            .navigationTitle("Log sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                Button("Save") {
                    app.logSleep(start: bed, end: wake, quality: quality)
                    dismiss()
                }
                .buttonStyle(.atlasPrimary)
                .disabled(minutes < 30)
                .accessibilityIdentifier("saveSleep")
                .gutter()
                .padding(.bottom, Theme.Space.xs)
            }
        }
    }

    private func symbol(_ q: Int) -> String {
        ["cloud.rain.fill", "cloud.fill", "cloud.sun.fill", "sun.max.fill", "sparkles"][q - 1]
    }

    private func word(_ q: Int) -> String {
        ["Awful", "Poor", "OK", "Good", "Great"][q - 1]
    }
}
