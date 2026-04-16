import SwiftUI

internal enum FloatingMicrophoneDockLayout {
    static func size(for status: AppStatus) -> CGSize {
        switch status {
        case .recording:
            return LayoutMetrics.FloatingDock.compactSize
        default:
            return LayoutMetrics.FloatingDock.expandedSize
        }
    }
}

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
    @AppStorage(AppDefaults.Keys.pressAndHoldEnabled) private var pressAndHoldEnabled =
        PressAndHoldConfiguration.defaults.enabled
    @AppStorage(AppDefaults.Keys.pressAndHoldKeyIdentifier) private var pressAndHoldKeyIdentifier =
        PressAndHoldConfiguration.defaults.key.rawValue

    let onPrimaryAction: () -> Void
    let onCancelAction: () -> Void
    let onSettingsAction: () -> Void

    private let shell = Color.black.opacity(0.84)
    private let shellBorder = Color.white.opacity(0.16)
    private let shellHighlight = Color.white.opacity(0.05)
    private let text = Color.white.opacity(0.96)
    private let mutedText = Color.white.opacity(0.62)
    private let subtleFill = Color.white.opacity(0.08)
    private let danger = Color(red: 0.95, green: 0.42, blue: 0.41)

    var body: some View {
        Group {
            if isRecording {
                recordingDock
            } else {
                expandedDock
            }
        }
        .frame(
            width: FloatingMicrophoneDockLayout.size(for: viewModel.status).width,
            height: FloatingMicrophoneDockLayout.size(for: viewModel.status).height
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isRecording)
        .animation(.easeInOut(duration: 0.18), value: viewModel.status)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    private var expandedDock: some View {
        VStack(spacing: 8) {
            Button(action: onPrimaryAction) {
                Text(primaryText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(text)
                    .lineLimit(1)
                    .padding(.horizontal, 18)
                    .frame(minWidth: 300)
                    .frame(height: 42)
                    .background(capsuleBackground)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.isPrimaryActionEnabled)
            .help(primaryButtonHelp)

            Button(action: onSettingsAction) {
                HStack(spacing: 4) {
                    ForEach(0..<8, id: \.self) { _ in
                        Circle()
                            .fill(mutedText)
                            .frame(width: 3, height: 3)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 28)
                .background(smallCapsuleBackground)
            }
            .buttonStyle(.plain)
            .help("Open VoiceFlow settings")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var recordingDock: some View {
        HStack(spacing: 10) {
            Button(action: onCancelAction) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(text)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(subtleFill)
                    )
            }
            .buttonStyle(.plain)
            .help("Cancel dictation")

            waveform

            Button(action: onPrimaryAction) {
                ZStack {
                    Circle()
                        .fill(danger)
                        .frame(width: 22, height: 22)

                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                }
                .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Stop and transcribe")
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(capsuleBackground)
    }

    private var capsuleBackground: some View {
        Capsule(style: .continuous)
            .fill(shell)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(shellBorder, lineWidth: 1)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(shellHighlight, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.3), radius: 14, y: 10)
    }

    private var smallCapsuleBackground: some View {
        Capsule(style: .continuous)
            .fill(shell)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(shellBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.22), radius: 10, y: 6)
    }

    private var waveform: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<10, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(text)
                    .frame(width: 3, height: barHeight(for: index))
            }
        }
        .frame(width: 58, height: 24)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let level = max(0.12, CGFloat(viewModel.audioLevel))
        let waveformPattern: [CGFloat] = [0.28, 0.46, 0.72, 0.94, 0.78, 0.52, 0.36, 0.68, 0.88, 0.58]
        let amplitude = waveformPattern[index % waveformPattern.count]
        return 5 + (level * amplitude * 11)
    }

    private var selectedPressAndHoldKey: PressAndHoldKey {
        PressAndHoldKey(rawValue: pressAndHoldKeyIdentifier) ?? PressAndHoldConfiguration.defaults.key
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
            return "Listening"
        case .processing:
            return "Transcribing…"
        case .success:
            return "Transcript ready"
        case .permissionRequired:
            return "Click to allow microphone"
        case .error(let message):
            return message
        case .downloadingModel(let message):
            return message
        case .ready:
            return readyPromptText
        }
    }

    private var readyPromptText: String {
        guard pressAndHoldEnabled else {
            return "Click to start dictating"
        }

        if selectedPressAndHoldKey == .globe {
            return "Click or hold fn to start dictating"
        }

        return "Click or use hotkey to start dictating"
    }

    private var primaryButtonHelp: String {
        switch viewModel.status {
        case .permissionRequired:
            return "Request microphone access"
        case .processing:
            return "VoiceFlow is transcribing"
        case .success:
            return "Ready for the next dictation"
        default:
            return "Start dictation"
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
        switch viewModel.status {
        case .recording:
            return "Use the left button to cancel or the right button to stop and transcribe."
        case .processing:
            return "VoiceFlow is currently processing audio."
        default:
            return "Click the main pill to start dictation. Use the smaller pill for settings."
        }
    }
}

#Preview("Floating Dock") {
    let viewModel = FloatingMicrophoneDockViewModel()
    viewModel.applyRecorderState(isRecording: false, audioLevel: 0, hasPermission: true)

    return FloatingMicrophoneDockView(
        viewModel: viewModel,
        onPrimaryAction: {},
        onCancelAction: {},
        onSettingsAction: {}
    )
    .padding(24)
    .background(Color.black)
}
