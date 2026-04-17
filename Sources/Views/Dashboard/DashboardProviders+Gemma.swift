import SwiftUI

extension DashboardProvidersView {
    // MARK: - Gemma Section
    @ViewBuilder
    var gemmaCard: some View {
        let repo = selectedGemmaModel.rawValue
        let isDownloaded = mlxModelManager.downloadedModels.contains(repo)
        let isDownloading = mlxModelManager.isDownloading[repo] ?? false
        let progressText = mlxModelManager.downloadProgress[repo]

        Group {
            LabeledContent("Environment") {
                HStack(spacing: 10) {
                    if isCheckingEnv {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Label(
                        envReady ? "Ready" : "Setup required",
                        systemImage: envReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(envReady ? Color(nsColor: .systemGreen) : Color(nsColor: .systemOrange))

                    if !envReady {
                        Button("Install…") {
                            runGemmaSetup()
                        }
                        .controlSize(.small)
                    } else {
                        Button(isVerifyingGemma ? "Verifying…" : "Verify") {
                            verifyGemmaModel()
                        }
                        .disabled(isVerifyingGemma)
                        .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            LabeledContent("Model") {
                HStack(spacing: 10) {
                    Picker("", selection: $selectedGemmaModel) {
                        ForEach(GemmaModel.allCases, id: \.self) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)

                    if isDownloading {
                        ProgressView().controlSize(.small)
                    } else if isDownloaded {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color(nsColor: .systemGreen))
                                .help("Downloaded")

                            Button {
                                mlxRepoToDelete = repo
                                showMLXDeleteConfirm = true
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .help("Delete model")
                        }
                    } else {
                        Button("Get") { downloadGemmaModel(repo) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Text(selectedGemmaModel.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let progressText, !progressText.isEmpty {
                Text(progressText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let msg = gemmaVerifyMessage, !msg.isEmpty {
                Text(msg)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if isDownloaded {
                ModelStorageInfoView(
                    path: HuggingFaceCache.modelDirectory(for: repo).path,
                    sizeText: mlxModelManager.modelSizes[repo].map { mlxModelManager.formatBytes($0) }
                )
            }

            Label(
                "Transcribes + corrects in one pass • Semantic correction is built-in",
                systemImage: "wand.and.stars"
            )
            .font(.caption2)
            .foregroundStyle(.secondary)

            Label(
                "Runs locally on Apple Silicon • \(selectedGemmaModel == .e2b ? "~3.2" : "~5") GB disk space",
                systemImage: "apple.logo"
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .onChange(of: selectedGemmaModel) { _, _ in
            gemmaVerifyMessage = nil
        }
    }

    // MARK: - Gemma Helpers

    private func runGemmaSetup() {
        setupStatus = "Installing Gemma dependencies…"
        setupLogs = ""
        isSettingUp = true
        showSetupSheet = true
        Task {
            do {
                _ = try UvBootstrap.ensureVenv(userPython: nil) { msg in
                    Task { @MainActor in
                        setupLogs += (setupLogs.isEmpty ? "" : "\n") + msg
                    }
                }
                await MainActor.run {
                    isSettingUp = false
                    setupStatus = "✓ Environment ready"
                    envReady = true
                    hasSetupGemma = true
                }
                try? await Task.sleep(for: .milliseconds(600))
                await MainActor.run { showSetupSheet = false }
            } catch {
                await MainActor.run {
                    isSettingUp = false
                    setupStatus = "✗ Setup failed"
                    setupLogs += "\nError: \(error.localizedDescription)"
                }
            }
        }
    }

    private func downloadGemmaModel(_ repo: String) {
        Task { await mlxModelManager.downloadModel(repo) }
    }

    func verifyGemmaModel() {
        isVerifyingGemma = true
        gemmaVerifyMessage = "Warming up Gemma model…"
        Task {
            do {
                try await MLDaemonManager.shared.warmup(
                    type: "gemma",
                    repo: selectedGemmaModel.rawValue
                )
                await MainActor.run {
                    isVerifyingGemma = false
                    gemmaVerifyMessage = "Model verified"
                    hasSetupGemma = true
                }
            } catch {
                await MainActor.run {
                    isVerifyingGemma = false
                    gemmaVerifyMessage = "Verification failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
