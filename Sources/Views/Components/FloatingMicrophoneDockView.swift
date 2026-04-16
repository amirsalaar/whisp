import SwiftUI

@MainActor
internal final class FloatingMicrophoneDockViewModel: ObservableObject {
    @Published private(set) var status: AppStatus = .ready
    @Published private(set) var audioLevel: Float = 0

    private var isRecording = false
    private var isProcessing = false
    private var hasPermission = true
    private var successResetTask: Task<Void, Never>?
    private let successResetDelay: Duration

    init(successResetDelay: Duration = .seconds(1.2)) {
        self.successResetDelay = successResetDelay
    }

    deinit {
        successResetTask?.cancel()
    }

    var isPrimaryActionEnabled: Bool {
        if case .processing = status {
            return false
        }

        return true
    }

    func applyRecorderState(isRecording: Bool, audioLevel: Float, hasPermission: Bool) {
        self.isRecording = isRecording
        self.audioLevel = audioLevel
        self.hasPermission = hasPermission

        if isRecording {
            isProcessing = false
            cancelSuccessReset()
        }

        refreshStatus()
    }

    func handleTranscriptionStarted() {
        isProcessing = true
        cancelSuccessReset()
        refreshStatus()
    }

    func handleTranscriptionCompleted() {
        isProcessing = false

        guard hasPermission else {
            refreshStatus()
            return
        }

        status = .success
        scheduleSuccessReset()
    }

    private func refreshStatus() {
        if isRecording {
            status = .recording
        } else if isProcessing {
            status = .processing("Transcribing...")
        } else if !hasPermission {
            status = .permissionRequired
        } else if case .success = status {
            return
        } else {
            status = .ready
        }
    }

    private func scheduleSuccessReset() {
        cancelSuccessReset()

        successResetTask = Task { @MainActor [weak self] in
            guard let self else { return }

            try? await Task.sleep(for: self.successResetDelay)
            guard !Task.isCancelled else { return }

            if self.isRecording {
                self.status = .recording
            } else if self.isProcessing {
                self.status = .processing("Transcribing...")
            } else if self.hasPermission {
                self.status = .ready
            } else {
                self.status = .permissionRequired
            }
        }
    }

    private func cancelSuccessReset() {
        successResetTask?.cancel()
        successResetTask = nil
    }
}

internal struct FloatingMicrophoneDockView: View {
    @ObservedObject var viewModel: FloatingMicrophoneDockViewModel

    let onPrimaryAction: () -> Void
    let onSettingsAction: () -> Void

    private let cream = Color(red: 0.98, green: 0.96, blue: 0.93)
    private let border = Color(red: 0.84, green: 0.81, blue: 0.77)
    private let ink = Color(red: 0.18, green: 0.15, blue: 0.13)
    private let muted = Color(red: 0.45, green: 0.42, blue: 0.39)
    private let accent = Color(red: 0.76, green: 0.42, blue: 0.32)

    var body: some View {
        HStack(spacing: 14) {
            dockOrb

            VStack(alignment: .leading, spacing: 3) {
                Text("VoiceFlow")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(muted)

                Text(primaryText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ink)
                    .lineLimit(1)

                Text(secondaryText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(muted)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button(action: onSettingsAction) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(muted)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.72))
                    )
            }
            .buttonStyle(.plain)
            .help("Open VoiceFlow settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: LayoutMetrics.FloatingDock.width, height: LayoutMetrics.FloatingDock.height)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(cream)
                .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(border, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 24))
        .onTapGesture {
            guard viewModel.isPrimaryActionEnabled else { return }
            onPrimaryAction()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    private var dockOrb: some View {
        ZStack {
            Circle()
                .fill(orbBackground)

            if isRecording {
                InkRippleView(audioLevel: viewModel.audioLevel, isActive: true)
                    .clipShape(Circle())
                    .padding(4)
            }

            Image(systemName: orbIcon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(orbForeground)
        }
        .frame(width: 52, height: 52)
    }

    private var isRecording: Bool {
        if case .recording = viewModel.status {
            return true
        }

        return false
    }

    private var primaryText: String {
        switch viewModel.status {
        case .recording:
            return "Listening everywhere"
        case .processing:
            return "Processing transcript"
        case .success:
            return "Transcript ready"
        case .permissionRequired:
            return "Microphone permission needed"
        case .error(let message):
            return message
        case .downloadingModel(let message):
            return message
        case .ready:
            return "Click to record"
        }
    }

    private var secondaryText: String {
        switch viewModel.status {
        case .recording:
            return "Release Fn or click again to stop."
        case .processing:
            return "VoiceFlow is transcribing in the background."
        case .success:
            return "Ready for the next dictation."
        case .permissionRequired:
            return "Click to request access, or open settings."
        case .error:
            return "Open settings to inspect the current setup."
        case .downloadingModel:
            return "Model downloads continue while the dock stays available."
        case .ready:
            return "Works across apps and all Spaces."
        }
    }

    private var orbBackground: Color {
        switch viewModel.status {
        case .recording:
            return accent
        case .processing:
            return accent.opacity(0.22)
        case .success:
            return Color.green.opacity(0.85)
        case .permissionRequired:
            return muted.opacity(0.18)
        case .error:
            return Color.red.opacity(0.18)
        case .downloadingModel:
            return accent.opacity(0.18)
        case .ready:
            return accent.opacity(0.16)
        }
    }

    private var orbForeground: Color {
        switch viewModel.status {
        case .recording, .success:
            return .white
        case .processing, .ready, .downloadingModel:
            return accent
        case .permissionRequired:
            return muted
        case .error:
            return .red
        }
    }

    private var orbIcon: String {
        switch viewModel.status {
        case .recording:
            return "stop.fill"
        case .processing:
            return "ellipsis"
        case .success:
            return "checkmark"
        case .permissionRequired:
            return "mic.slash.fill"
        case .error:
            return "exclamationmark"
        case .downloadingModel, .ready:
            return "mic.fill"
        }
    }

    private var accessibilityLabel: String {
        switch viewModel.status {
        case .recording:
            return "VoiceFlow dock, currently recording"
        case .processing:
            return "VoiceFlow dock, processing transcript"
        case .success:
            return "VoiceFlow dock, transcription completed"
        case .permissionRequired:
            return "VoiceFlow dock, microphone permission required"
        case .error(let message):
            return "VoiceFlow dock, error: \(message)"
        case .downloadingModel(let message):
            return "VoiceFlow dock, model download in progress: \(message)"
        case .ready:
            return "VoiceFlow dock, ready to record"
        }
    }

    private var accessibilityHint: String {
        if viewModel.isPrimaryActionEnabled {
            return "Click to start or stop recording. Use the settings button for configuration."
        }

        return "VoiceFlow is currently processing audio."
    }
}

#Preview("Floating Dock") {
    let viewModel = FloatingMicrophoneDockViewModel()
    viewModel.applyRecorderState(isRecording: false, audioLevel: 0, hasPermission: true)

    return FloatingMicrophoneDockView(
        viewModel: viewModel,
        onPrimaryAction: {},
        onSettingsAction: {}
    )
    .padding(24)
    .background(Color.gray.opacity(0.25))
}
