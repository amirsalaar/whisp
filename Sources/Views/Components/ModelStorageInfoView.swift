import SwiftUI

internal struct ModelStorageInfoView: View {
    let path: String
    let sizeText: String?

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                if let sizeText {
                    Text("Storage: \(sizeText)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(abbreviatedPath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            Spacer()

            Button {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
            } label: {
                Label("Show in Finder", systemImage: "folder")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
            .help("Open in Finder")
        }
    }

    private var abbreviatedPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
