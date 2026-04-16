import SwiftUI

extension DashboardProvidersView {
    // MARK: - Whisper MLX Section
    @ViewBuilder
    var whisperMLXCard: some View {
        let repo = selectedWhisperMLXModel.repoId
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
                            runWhisperMLXSetup()
                        }
                        .controlSize(.small)
                    } else {
                        Button(isVerifyingWhisperMLX ? "Verifying…" : "Verify") {
                            verifyWhisperMLXModel()
                        }
                        .disabled(isVerifyingWhisperMLX)
                        .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            LabeledContent("Model") {
                HStack(spacing: 10) {
                    Picker("", selection: $selectedWhisperMLXModel) {
                        ForEach(WhisperMLXModel.allCases, id: \.self) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)

                    if isDownloading {
                        ProgressView().controlSize(.small)
                    } else if isDownloaded {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color(nsColor: .systemGreen))
                            .help("Downloaded")
                    } else {
                        Button("Get") { downloadWhisperMLXModel(repo) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Text(selectedWhisperMLXModel.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let progressText, !progressText.isEmpty {
                Text(progressText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let msg = whisperMLXVerifyMessage, !msg.isEmpty {
                Text(msg)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Label(
                "Sub-second transcription on Apple Silicon",
                systemImage: "bolt.fill"
            )
            .font(.caption2)
            .foregroundStyle(.secondary)

            Label(
                "Runs locally on Apple Silicon • \(whisperMLXModelSizeLabel)",
                systemImage: "apple.logo"
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .onChange(of: selectedWhisperMLXModel) { _, _ in
            whisperMLXVerifyMessage = nil
        }
    }

    // MARK: - Whisper MLX Helpers

    private var whisperMLXModelSizeLabel: String {
        switch selectedWhisperMLXModel {
        case .base: return "~144 MB disk space"
        case .small: return "~481 MB disk space"
        case .largeTurbo: return "~1.6 GB disk space"
        }
    }

    private func runWhisperMLXSetup() {
        setupStatus = "Installing Whisper MLX dependencies…"
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
                    hasSetupWhisperMLX = true
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

    private func downloadWhisperMLXModel(_ repo: String) {
        Task { await mlxModelManager.downloadModel(repo) }
    }

    func verifyWhisperMLXModel() {
        isVerifyingWhisperMLX = true
        whisperMLXVerifyMessage = "Warming up Whisper MLX model…"
        Task {
            do {
                try await MLDaemonManager.shared.warmup(
                    type: "whisper_mlx",
                    repo: selectedWhisperMLXModel.rawValue
                )
                await MainActor.run {
                    isVerifyingWhisperMLX = false
                    whisperMLXVerifyMessage = "Model verified"
                    hasSetupWhisperMLX = true
                }
            } catch {
                await MainActor.run {
                    isVerifyingWhisperMLX = false
                    whisperMLXVerifyMessage = "Verification failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
