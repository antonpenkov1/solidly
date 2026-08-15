import SwiftUI

struct DiaperSheet: View {
    let childId: UUID
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: DiaperKind = .wet
    @State private var date = Date()
    @State private var note = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    Picker("", selection: $kind) {
                        Text("Wet").tag(DiaperKind.wet)
                        Text("Dirty").tag(DiaperKind.dirty)
                        Text("Both").tag(DiaperKind.mixed)
                        Text("Dry").tag(DiaperKind.dry)
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel("When")
                        DatePicker("", selection: $date, in: ...Date())
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel("Note")
                        TextField(String(localized: "Optional"), text: $note)
                            .font(.system(size: 15))
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.card))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Theme.hairline, lineWidth: 1))
                    }

                    Text("Six or more wet nappies a day is the usual sign that a young baby is getting enough milk.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.faint)

                    Button {
                        StorageWorker.shared.save(diaper: DiaperEntry(
                            childId: childId, date: date, kind: kind, note: note))
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        onSaved()
                        dismiss()
                    } label: {
                        Text("Save")
                            .font(Theme.rounded(17, .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Capsule().fill(Theme.accent))
                            .foregroundStyle(Theme.bg)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(Theme.gutter)
            }
            .navigationTitle(String(localized: "Nappy"))
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
