import SwiftUI

internal struct PersonalDictionaryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let store: PersonalDictionaryStore

    @State private var draftEntries: [DraftEntry]
    @State private var saveError: String?

    init(store: PersonalDictionaryStore = .shared) {
        self.store = store
        _draftEntries = State(initialValue: store.entries.map(DraftEntry.init))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(
                    "Use this for names, brands, acronyms, and special words. Avoid broad common words, because exact aliases are enforced after semantic correction."
                )
                .font(.callout)
                .foregroundStyle(.secondary)

                if let saveError {
                    Text(saveError)
                        .font(.callout)
                        .foregroundStyle(Color(nsColor: .systemRed))
                }

                if draftEntries.isEmpty {
                    ContentUnavailableView(
                        "No Terms Yet",
                        systemImage: "text.badge.plus",
                        description: Text(
                            "Add a preferred spelling and any spoken or mistyped variants you want Whisp to normalize."
                        )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach($draftEntries) { $entry in
                                GroupBox {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack(alignment: .top, spacing: 12) {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text("Preferred spelling")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                TextField(
                                                    "Whisp",
                                                    text: $entry.preferredText
                                                )
                                            }

                                            Button(role: .destructive) {
                                                removeEntry(id: entry.id)
                                            } label: {
                                                Image(systemName: "trash")
                                            }
                                            .buttonStyle(.borderless)
                                            .help("Remove term")
                                        }

                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("Aliases")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            TextField(
                                                "Comma-separated variants, for example: wisp, whispp",
                                                text: $entry.aliasesText
                                            )
                                            Text(
                                                "Use exact variants separated by commas. Preferred spelling is enforced after correction."
                                            )
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                HStack {
                    Button {
                        addEntry()
                    } label: {
                        Label("Add Term", systemImage: "plus")
                    }

                    Spacer()
                }
            }
            .padding(20)
            .navigationTitle("Personal Dictionary")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                }
            }
        }
        .frame(minWidth: 700, minHeight: 460)
    }

    private func addEntry() {
        saveError = nil
        draftEntries.append(DraftEntry(preferredText: "", aliasesText: ""))
    }

    private func removeEntry(id: UUID) {
        saveError = nil
        draftEntries.removeAll { $0.id == id }
    }

    private func save() {
        saveError = nil

        let hasIncompleteEntry = draftEntries.contains {
            normalized($0.preferredText).isEmpty && !normalized($0.aliasesText).isEmpty
        }
        if hasIncompleteEntry {
            saveError = "Each term needs a preferred spelling before it can be saved."
            return
        }

        let entries = draftEntries.map {
            PersonalDictionaryEntry(
                id: $0.id,
                preferredText: $0.preferredText,
                aliases: parseAliases($0.aliasesText)
            )
        }
        guard store.replaceAll(entries) else {
            saveError = "Couldn't save your personal dictionary. Check disk access and try again."
            return
        }
        dismiss()
    }

    private func parseAliases(_ text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct DraftEntry: Identifiable {
    let id: UUID
    var preferredText: String
    var aliasesText: String

    init(id: UUID = UUID(), preferredText: String, aliasesText: String) {
        self.id = id
        self.preferredText = preferredText
        self.aliasesText = aliasesText
    }

    init(_ entry: PersonalDictionaryEntry) {
        self.id = entry.id
        self.preferredText = entry.preferredText
        self.aliasesText = entry.aliases.joined(separator: ", ")
    }
}
