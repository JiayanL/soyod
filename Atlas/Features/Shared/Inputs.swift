import SwiftUI

/// Large numeric input with unit, used in onboarding and log sheets.
struct NumberField: View {
    let label: String
    @Binding var value: Double
    var unit: String
    var decimals: Int = 1
    var identifier: String? = nil

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            MicroLabel(label)
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.xxs) {
                TextField("0", value: $value, format: .number.precision(.fractionLength(0...decimals)))
                    .keyboardType(decimals > 0 ? .decimalPad : .numberPad)
                    .textStyle(.metricL)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .focused($focused)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(label)
                    .accessibilityIdentifier(identifier ?? label)
                Text(unit)
                    .textStyle(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .padding(Theme.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.fill, in: .rect(cornerRadius: Theme.Radius.inner, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
                .strokeBorder(focused ? Theme.Palette.textPrimary.opacity(0.6) : .clear, lineWidth: 1)
        }
        .contentShape(.rect)
        .onTapGesture { focused = true }
    }
}

/// mm:ss input for time-based goals (canonical seconds).
struct DurationField: View {
    let label: String
    @Binding var seconds: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            MicroLabel(label)
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.xxs) {
                TextField("0", value: minutes, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .fixedSize()
                    .accessibilityLabel("\(label) minutes")
                Text(":").foregroundStyle(Theme.Palette.textSecondary)
                TextField("00", value: secs, format: .number.precision(.integerLength(2)))
                    .keyboardType(.numberPad)
                    .fixedSize()
                    .accessibilityLabel("\(label) seconds")
                Spacer(minLength: 0)
            }
            .textStyle(.metricL)
            .foregroundStyle(Theme.Palette.textPrimary)
        }
        .padding(Theme.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.fill, in: .rect(cornerRadius: Theme.Radius.inner, style: .continuous))
    }

    private var minutes: Binding<Int> {
        Binding(get: { Int(seconds) / 60 }, set: { seconds = Double(max(0, $0) * 60 + Int(seconds) % 60) })
    }

    private var secs: Binding<Int> {
        Binding(get: { Int(seconds) % 60 }, set: { seconds = Double(Int(seconds) / 60 * 60 + min(59, max(0, $0))) })
    }
}

/// Selectable full-width row (activity level etc.).
struct OptionRow: View {
    let title: String
    var subtitle: String? = nil
    var symbol: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.s) {
                if let symbol {
                    Image(systemName: symbol)
                        .icon(Theme.Icon.regular)
                        .foregroundStyle(selected ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                        .frame(width: Theme.Size.directiveIcon)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .textStyle(.headline)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .textStyle(.footnote)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                Spacer(minLength: Theme.Space.xs)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .icon(Theme.Icon.large, weight: .regular)
                    .foregroundStyle(selected ? Theme.Palette.textPrimary : Theme.Palette.textTertiary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, Theme.Space.m)
            .padding(.vertical, Theme.Space.s)
            .frame(minHeight: 56)
            .background(Theme.Palette.fill, in: .rect(cornerRadius: Theme.Radius.inner, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
                    .strokeBorder(selected ? Theme.Palette.textPrimary : .clear, lineWidth: 1.5)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: selected)
    }
}

/// Wrapping chip picker (single or multi select).
struct ChipPicker<Value: Hashable>: View {
    let options: [(Value, String)]
    let isSelected: (Value) -> Bool
    let toggle: (Value) -> Void

    var body: some View {
        FlowLayout(spacing: Theme.Space.xs) {
            ForEach(options, id: \.0) { option in
                Button(option.1) { toggle(option.0) }
                    .buttonStyle(ChipButtonStyle(selected: isSelected(option.0)))
                    .accessibilityAddTraits(isSelected(option.0) ? .isSelected : [])
            }
        }
    }
}

/// Labelled form group for sheets.
struct FormGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            MicroLabel(title)
            content()
        }
    }
}

/// Sheet chrome: title + close + optional trailing.
struct SheetHeader: View {
    let title: String
    var subtitle: String? = nil
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .textStyle(.serifTitle)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .textStyle(.footnote)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            Spacer()
            IconButton(symbol: "xmark", label: "Close", action: onClose)
        }
        .padding(.top, Theme.Space.l)
    }
}
