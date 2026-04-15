import AVFoundation
import AppKit
import os.log

internal class PermissionChecker {

    /// Check all required permissions at app startup
    static func checkAndPromptForPermissions() {
        // Request microphone permission using system prompt
        Task {
            let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            if micStatus == .notDetermined {
                _ = await AVCaptureDevice.requestAccess(for: .audio)
            }
        }

        let configuration = PressAndHoldSettings.configuration()
        let needsInputMonitoring = configuration.requiresInputMonitoringPermission(
            warningAcknowledged: FnGlobeHotkeyPreferenceStore.warningAcknowledged()
        )
        let needsAccessibility =
            UserDefaults.standard.bool(forKey: AppDefaults.Keys.enableSmartPaste)
            || configuration.requiresAccessibilityPermission

        if needsInputMonitoring {
            let inputMonitoringPermissionManager = InputMonitoringPermissionManager()
            if !inputMonitoringPermissionManager.checkPermission() {
                _ = inputMonitoringPermissionManager.requestPermission()
            }
        }

        guard needsAccessibility else { return }

        // Request accessibility permission using system prompt
        // kAXTrustedCheckOptionPrompt triggers the native system dialog
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Request microphone permission explicitly
    static func requestMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    /// Check if accessibility permission is granted
    static func hasAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }
}
