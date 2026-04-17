import SwiftUI

internal struct MLXModelManagementView: View {
    @State private var modelManager = MLXModelManager.shared
    @Binding var selectedModelRepo: String
    @State private var isRefreshing = false
    @State private var repoToDelete: String?
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "square.and.arrow.down.fill")
                    .foregroundStyle(.blue)
                    .font(.title3)
                Text("MLX Models")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                if modelManager.totalCacheSize > 0 {
                    Text(modelManager.formatBytes(modelManager.totalCacheSize))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }

                Button(action: {
                    isRefreshing = true
                    Task {
                        await modelManager.refreshModelList()
                        await MainActor.run {
                            isRefreshing = false
                        }
                    }
                }) {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing)
                .help("Refresh model list to check downloaded models")
            }

            // Model List (shared row UI using adapters)
            VStack(spacing: 8) {
                let entries: [ModelEntry] = MLXModelManager.recommendedModels.map { m in
                    let startDownload = {
                        Task { @MainActor in
                            modelManager.isDownloading[m.repo] = true
                            modelManager.downloadProgress[m.repo] = "Starting download..."
                        }
                        Task { await modelManager.downloadModel(m.repo) }
                    }

                    return MLXEntry(
                        model: m,
                        isDownloaded: modelManager.downloadedModels.contains(m.repo),
                        isDownloading: modelManager.isDownloading[m.repo] ?? false,
                        statusText: modelManager.downloadProgress[m.repo],
                        sizeText: (modelManager.modelSizes[m.repo]).map(MLXModelManager.shared.formatBytes)
                            ?? m.estimatedSize,
                        isSelected: selectedModelRepo == m.repo,
                        badgeText: isRecommended(m.repo) ? "RECOMMENDED" : nil,
                        onSelect: {
                            selectedModelRepo = m.repo
                            if !modelManager.downloadedModels.contains(m.repo) {
                                startDownload()
                            }
                        },
                        onDownload: startDownload,
                        onDelete: {
                            repoToDelete = m.repo
                            showDeleteConfirm = true
                        }
                    )
                }
                ForEach(entries.indices, id: \.self) { i in
                    let e = entries[i]
                    UnifiedModelRow(
                        title: e.title,
                        subtitle: e.subtitle,
                        sizeText: e.sizeText,
                        statusText: e.statusText,
                        statusColor: e.statusColor,
                        isDownloaded: e.isDownloaded,
                        isDownloading: e.isDownloading,
                        isSelected: e.isSelected,
                        badgeText: e.badgeText,
                        onSelect: e.onSelect,
                        onDownload: e.onDownload,
                        onDelete: e.onDelete
                    )
                }
            }

            // Info text with clickable path
            VStack(alignment: .leading, spacing: 4) {
                ModelStorageInfoView(
                    path: HuggingFaceCache.hubDirectory().path,
                    sizeText: modelManager.totalCacheSize > 0
                        ? modelManager.formatBytes(modelManager.totalCacheSize) : nil
                )
            }
        }
        .confirmationDialog(
            "Delete \(repoToDelete?.split(separator: "/").last.map(String.init) ?? "model")?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let repo = repoToDelete {
                    Task {
                        await modelManager.deleteModel(repo)
                        if selectedModelRepo == repo {
                            selectedModelRepo = AppDefaults.defaultSemanticCorrectionModelRepo
                        }
                    }
                }
                repoToDelete = nil
            }
            Button("Cancel", role: .cancel) { repoToDelete = nil }
        } message: {
            if let repo = repoToDelete, let size = modelManager.modelSizes[repo] {
                Text(
                    "This will remove the model (\(modelManager.formatBytes(size))) from disk. You can re-download it later."
                )
            } else {
                Text("This will remove the model from disk. You can re-download it later.")
            }
        }
    }

    private func isRecommended(_ repo: String) -> Bool {
        return repo == AppDefaults.defaultSemanticCorrectionModelRepo
    }
}
