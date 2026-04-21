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
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: DashboardTheme.Spacing.lg) {
                        editorHeader

                        if let saveError {
                            errorBanner(saveError)
                        }

                        if draftEntries.isEmpty {
                            emptyStateCard
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Terms")
                                    .font(DashboardTheme.Fonts.serif(18, weight: .semibold))
                                    .foregroundStyle(DashboardTheme.ink)

                                ForEach(Array(draftEntries.enumerated()), id: \.element.id) { index, _ in
                                    entryCard(entry: $draftEntries[index], index: index)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                footerBar
            }
            .background(DashboardTheme.pageBg)
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
        .frame(minWidth: 760, minHeight: 560)
    }

    private var editorHeader: some View {
        editorCard {
            VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
                HStack(alignment: .top, spacing: DashboardTheme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Build a Glossary Whisp Can Trust")
                            .font(DashboardTheme.Fonts.serif(24, weight: .semibold))
                            .foregroundStyle(DashboardTheme.ink)

                        Text(
                            "Use exact aliases for names, brands, acronyms, and team vocabulary. Keep entries specific so the final canonicalization pass stays precise."
                        )
                        .font(DashboardTheme.Fonts.sans(13, weight: .regular))
                        .foregroundStyle(DashboardTheme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: DashboardTheme.Spacing.md)

                    Text(
                        draftEntries.isEmpty
                            ? "Empty glossary"
                            : "\(draftEntries.count) draft \(draftEntries.count == 1 ? "term" : "terms")"
                    )
                    .font(DashboardTheme.Fonts.mono(11, weight: .semibold))
                    .foregroundStyle(DashboardTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(DashboardTheme.accentLight))
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        headerTag("Names")
                        headerTag("Brands")
                        headerTag("Acronyms")
                        headerTag("Internal jargon")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        headerTag("Names")
                        headerTag("Brands")
                        headerTag("Acronyms")
                        headerTag("Internal jargon")
                    }
                }
            }
        }
    }

    private var emptyStateCard: some View {
        editorCard {
            VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
                ContentUnavailableView(
                    "No Terms Yet",
                    systemImage: "text.badge.plus",
                    description: Text(
                        "Add a preferred spelling and any spoken or mistyped variants you want Whisp to normalize."
                    )
                )
                .frame(maxWidth: .infinity)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: DashboardTheme.Spacing.md) {
                        starterExample(preferredText: "Whisp", aliases: ["wisp", "whispp"])
                        starterExample(preferredText: "OpenAI", aliases: ["open ai"])
                    }

                    VStack(spacing: DashboardTheme.Spacing.md) {
                        starterExample(preferredText: "Whisp", aliases: ["wisp", "whispp"])
                        starterExample(preferredText: "OpenAI", aliases: ["open ai"])
                    }
                }
            }
        }
    }

    private var footerBar: some View {
        HStack(spacing: DashboardTheme.Spacing.md) {
            Text(
                draftEntries.isEmpty
                    ? "No draft terms yet. Add one to get started."
                    : "\(draftEntries.count) \(draftEntries.count == 1 ? "draft term" : "draft terms") ready to save."
            )
            .font(DashboardTheme.Fonts.sans(12, weight: .regular))
            .foregroundStyle(DashboardTheme.inkMuted)

            Spacer()

            Button {
                addEntry()
            } label: {
                Label(draftEntries.isEmpty ? "Add First Term" : "Add Another Term", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .background(.bar)
    }

    private func entryCard(entry: Binding<DraftEntry>, index: Int) -> some View {
        let draft = entry.wrappedValue
        let preferredText = normalized(draft.preferredText)

        return editorCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Text(String(format: "%02d", index + 1))
                        .font(DashboardTheme.Fonts.mono(11, weight: .semibold))
                        .foregroundStyle(DashboardTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(DashboardTheme.accentLight))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(preferredText.isEmpty ? "Untitled term" : preferredText)
                            .font(DashboardTheme.Fonts.serif(18, weight: .semibold))
                            .foregroundStyle(DashboardTheme.ink)

                        Text(aliasSummary(for: draft.aliasesText))
                            .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                            .foregroundStyle(DashboardTheme.inkMuted)
                    }

                    Spacer()

                    Button(role: .destructive) {
                        removeEntry(id: draft.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove term")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Preferred spelling")
                        .font(DashboardTheme.Fonts.sans(12, weight: .semibold))
                        .foregroundStyle(DashboardTheme.inkMuted)

                    TextField("Whisp", text: entry.preferredText)
                        .textFieldStyle(.roundedBorder)
                        .font(DashboardTheme.Fonts.sans(13, weight: .regular))
                        .accessibilityLabel("Preferred spelling")
                        .accessibilityHint("The exact text Whisp should use in the final transcript.")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Aliases")
                        .font(DashboardTheme.Fonts.sans(12, weight: .semibold))
                        .foregroundStyle(DashboardTheme.inkMuted)

                    TextField(
                        "Comma-separated variants, for example: wisp, whispp",
                        text: entry.aliasesText
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(DashboardTheme.Fonts.sans(13, weight: .regular))
                    .accessibilityLabel("Aliases")
                    .accessibilityHint(
                        "Comma-separated variants that should normalize to the preferred spelling.")

                    Text(
                        "Use exact variants separated by commas. Preferred spelling is enforced after correction."
                    )
                    .font(DashboardTheme.Fonts.sans(11, weight: .regular))
                    .foregroundStyle(DashboardTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func editorCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DashboardTheme.cardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(DashboardTheme.rule.opacity(0.6), lineWidth: 1)
        )
    }

    private func headerTag(_ text: String) -> some View {
        Text(text)
            .font(DashboardTheme.Fonts.mono(11, weight: .semibold))
            .foregroundStyle(DashboardTheme.inkLight)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(DashboardTheme.cardBgAlt))
    }

    private func starterExample(preferredText: String, aliases: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(preferredText)
                .font(DashboardTheme.Fonts.serif(17, weight: .semibold))
                .foregroundStyle(DashboardTheme.ink)

            Text("Heard as: \(aliases.joined(separator: " • "))")
                .font(DashboardTheme.Fonts.mono(12, weight: .regular))
                .foregroundStyle(DashboardTheme.inkLight)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DashboardTheme.accentSubtle)
        )
    }

    private func errorBanner(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(nsColor: .systemRed))

            Text(text)
                .font(DashboardTheme.Fonts.sans(12, weight: .semibold))
                .foregroundStyle(Color(nsColor: .systemRed))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .systemRed).opacity(0.1))
        )
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

    private func aliasSummary(for text: String) -> String {
        let aliases = parseAliases(text)

        if aliases.isEmpty {
            return "No aliases yet. Add exact dictated or mistyped variants."
        }

        return aliases.count == 1 ? "1 alias configured" : "\(aliases.count) aliases configured"
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
