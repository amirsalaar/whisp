import SwiftUI

internal struct DashboardDictionaryView: View {
    @AppStorage(AppDefaults.Keys.personalDictionaryEnabled) private var personalDictionaryEnabled = true
    @AppStorage(AppDefaults.Keys.semanticCorrectionMode) private var semanticCorrectionModeRaw = AppDefaults
        .defaultSemanticCorrectionMode.rawValue

    @State private var personalDictionaryStore = PersonalDictionaryStore.shared
    @State private var showEditorSheet = false

    var body: some View {
        Form {
            Section("Personal Dictionary") {
                Toggle(isOn: $personalDictionaryEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Personal Dictionary")
                        Text("Keep preferred spellings for names, brands, acronyms, and special terms.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(alignment: .center, spacing: 12) {
                    let status = personalDictionaryStatus()

                    Label(status.text, systemImage: status.symbol)
                        .foregroundStyle(status.color)

                    Spacer()

                    Button(personalDictionaryStore.entries.isEmpty ? "Add Terms…" : "Manage Terms…") {
                        showEditorSheet = true
                    }
                    .controlSize(.small)
                }

                if let storagePath = personalDictionaryStore.storagePath {
                    Text("Stored at: \(displayHomeRelativePath(storagePath))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Section("How It Works") {
                Text(
                    "The personal dictionary is applied after semantic correction so configured spellings stay stable across engines."
                )
                .font(.callout)

                Text(
                    "When cloud correction is enabled, dictionary terms may be sent to your selected provider."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showEditorSheet) {
            PersonalDictionaryEditorSheet(store: personalDictionaryStore)
        }
    }

    private func personalDictionaryStatus() -> (text: String, symbol: String, color: Color) {
        let mode = SemanticCorrectionMode(rawValue: semanticCorrectionModeRaw) ?? .off
        let entryCount = personalDictionaryStore.entries.count

        if mode == .off {
            return (
                "Inactive while semantic correction is off.",
                "pause.circle.fill",
                Color(nsColor: .systemOrange)
            )
        }

        if !personalDictionaryEnabled {
            return ("Personal dictionary disabled.", "xmark.circle.fill", Color.secondary)
        }

        if entryCount == 0 {
            return ("No terms configured yet.", "text.badge.plus", Color.secondary)
        }

        let countLabel = entryCount == 1 ? "1 term ready." : "\(entryCount) terms ready."
        return (countLabel, "checkmark.circle.fill", Color(nsColor: .systemGreen))
    }
}

#Preview {
    DashboardDictionaryView()
        .frame(width: 900, height: 700)
}
