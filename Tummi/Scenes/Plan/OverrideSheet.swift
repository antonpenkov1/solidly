import SwiftUI

/// The "my paediatrician said otherwise" editor.
///
/// The framing matters: the app is not asking the parent to argue with the guidance, it is
/// recording the plan their own doctor gave for their own baby. The published range stays
/// visible everywhere afterwards, marked as the alternative.
struct OverrideSheet: View {
    let title: String
    let explanation: String
    let unitLabel: String
    let initialValue: Double
    let onSave: (Double, String) -> Void
    let onClear: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var valueText: String
    @State private var attribution: String = ""

    init(title: String, explanation: String, unitLabel: String, initialValue: Double,
         attribution: String = "",
         onSave: @escaping (Double, String) -> Void, onClear: @escaping () -> Void) {
        self.title = title
        self.explanation = explanation
        self.unitLabel = unitLabel
        self.initialValue = initialValue
        self.onSave = onSave
        self.onClear = onClear
        _valueText = State(initialValue: String(format: "%.0f", initialValue))
        _attribution = State(initialValue: attribution)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(explanation)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel("Value")
                            HStack(spacing: 8) {
                                TextField("0", text: $valueText)
                                    .keyboardType(.decimalPad)
                                    .font(Theme.serif(32, .medium))
                                    .frame(maxWidth: 130)
                                Text(unitLabel)
                                    .font(Theme.rounded(15, .medium))
                                    .foregroundStyle(Theme.faint)
                                Spacer()
                            }
                            Hairline()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel("Who said so")
                            TextField(String(localized: "e.g. Dr Ivanova, 12 Aug"), text: $attribution)
                                .font(.system(size: 15))
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Theme.card))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Theme.hairline, lineWidth: 1))
                            Text("Shown next to every number this changes, so you can always tell your doctor's plan from the published ranges.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.faint)
                        }

                        Button {
                            if let value = Double(valueText.replacingOccurrences(of: ",", with: ".")) {
                                onSave(value, attribution)
                            }
                            dismiss()
                        } label: {
                            Text("Use my doctor's number")
                                .font(Theme.rounded(16, .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Capsule().fill(Theme.indigo))
                                .foregroundStyle(Theme.bg)
                        }
                        .buttonStyle(.plain)

                        Button {
                            onClear()
                            dismiss()
                        } label: {
                            Text("Go back to published guidance")
                                .font(Theme.rounded(15, .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundStyle(Theme.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(Theme.gutter)
                    .readableWidth()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
            }
            .keyboardDoneButton()
        }
    }
}
