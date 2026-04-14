import SwiftUI
import AVFoundation
import ApplicationServices
import AppKit

internal struct DashboardPermissionsView: View {
    @State private var microphoneStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var isAccessibilityTrusted: Bool = AXIsProcessTrusted()
    @AppStorage("enableSmartPaste") private var enableSmartPaste = false
    @AppStorage("pressAndHoldEnabled") private var pressAndHoldEnabled = true

    var body: some View {
        Form {
            Section {
                LabeledContent("Status") {
                    permissionLabel(
                        isGranted: microphoneStatus == .authorized,
                        grantedText: "Granted",
                        requiredText: microphoneStatus == .denied ? "Denied" : "Required"
                    )
                }

                HStack(spacing: 10) {
                    Button("Request Access") {
                        requestMicrophonePermission()
                    }
                    .disabled(microphoneStatus == .authorized)

                    Button("Open Settings") {
                        openSystemSettings(path: "Privacy_Microphone")
                    }
                }
            } header: {
                Text("Microphone")
            } footer: {
                Text("VoiceFlow needs microphone access to record audio for transcription.")
            }

            if enableSmartPaste || pressAndHoldEnabled {
                Section {
                    LabeledContent("Status") {
                        permissionLabel(
                            isGranted: isAccessibilityTrusted,
                            grantedText: "Granted",
                            requiredText: "Required"
                        )
                    }

                    HStack(spacing: 10) {
                        Button("Open Settings") {
                            openSystemSettings(path: "Privacy_Accessibility")
                        }

                        Button("Refresh") {
                            refreshStatuses()
                        }
                    }
                } header: {
                    Text("Accessibility")
                } footer: {
                    if pressAndHoldEnabled && enableSmartPaste {
                        Text("Required for Press & Hold key detection and Smart Paste.")
                    } else if pressAndHoldEnabled {
                        Text("Required for Press & Hold key detection. Without this permission, the shortcut key won't work.")
                    } else {
                        Text("Required for Smart Paste to type into other apps.")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refreshStatuses)
        .onChange(of: enableSmartPaste) { _, _ in
            refreshStatuses()
        }
        .onChange(of: pressAndHoldEnabled) { _, _ in
            refreshStatuses()
        }
    }

    private func permissionLabel(isGranted: Bool, grantedText: String, requiredText: String) -> some View {
        Label(isGranted ? grantedText : requiredText, systemImage: isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .foregroundStyle(isGranted ? Color(nsColor: .systemGreen) : Color(nsColor: .systemOrange))
    }

    private func refreshStatuses() {
        microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        isAccessibilityTrusted = AXIsProcessTrusted()
    }

    private func requestMicrophonePermission() {
        guard !AppEnvironment.isRunningTests else { return }
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            Task { @MainActor in
                microphoneStatus = granted ? .authorized : .denied
            }
        }
    }

    private func openSystemSettings(path: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(path)") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

#Preview {
    DashboardPermissionsView()
        .frame(width: 900, height: 700)
}

