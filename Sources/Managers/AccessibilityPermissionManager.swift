import Foundation
import AppKit
import ApplicationServices

/// Dedicated manager for handling Accessibility permissions with proper explanations and error handling
internal class AccessibilityPermissionManager {
    private let isTestEnvironment: Bool
    private let permissionCheck: () -> Bool
    
    init(permissionCheck: @escaping () -> Bool = { AXIsProcessTrustedWithOptions(nil) }) {
        isTestEnvironment = NSClassFromString("XCTestCase") != nil
        self.permissionCheck = permissionCheck
    }
    
    /// Checks if the app has Accessibility permission without prompting the user
    /// - Returns: true if permission is granted, false otherwise
    func checkPermission() -> Bool {
        // Check without prompting user - never bypass this check
        return permissionCheck()
    }
    
    /// Requests Accessibility permission with a proper explanation dialog
    /// - Parameter completion: Called with the result of the permission request
    func requestPermissionWithExplanation(completion: @escaping (Bool) -> Void) {
        // First check if already granted
        if checkPermission() {
            completion(true)
            return
        }
        
        // In tests, do not show any dialogs
        if isTestEnvironment {
            completion(false)
            return
        }
        
        // Show explanation alert before requesting permission (runtime only)
        showPermissionExplanationAlert { [weak self] userWantsToGrant in
            guard userWantsToGrant else {
                completion(false)
                return
            }
            
            // Request permission with system prompt
            self?.requestPermissionFromSystem(completion: completion)
        }
    }
    
    /// Shows a detailed explanation of why Accessibility permission is needed
    private func showPermissionExplanationAlert(completion: @escaping (Bool) -> Void) {
        if isTestEnvironment { completion(false); return }
        Task { @MainActor in
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required for SmartPaste"
            alert.informativeText = """
            VoiceFlow's SmartPaste feature needs Accessibility permission to automatically paste transcribed text into your applications.
            
            🎯 What SmartPaste Does:
            • Automatically pastes transcribed text into the app you were using before recording
            • Switches focus back to your original application seamlessly
            • Provides a hands-free voice-to-text workflow
            
            🔒 Privacy Protection:
            • VoiceFlow ONLY sends paste commands (⌘V) to applications
            • It never reads, monitors, or accesses content from other applications
            • No screen recording or keylogging occurs
            • All transcription happens locally on your device
            
            ⚙️ What Happens Next:
            • Click "Grant Permission" to open System Settings
            • Find VoiceFlow in Privacy & Security → Accessibility
            • Toggle the switch to enable the permission
            • Return to VoiceFlow to use SmartPaste
            
            ✋ Alternative:
            If you prefer manual control, click "Continue Without SmartPaste" and use ⌘V to paste transcribed text yourself.
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Grant Permission")
            alert.addButton(withTitle: "Continue Without SmartPaste")
            alert.addButton(withTitle: "Learn More About Accessibility Permissions")
            
            let response = alert.runModal()
            
            switch response {
            case .alertFirstButtonReturn:
                completion(true)
            case .alertSecondButtonReturn:
                completion(false)
            case .alertThirdButtonReturn:
                self.showAccessibilityPermissionEducation()
                // After education, ask again
                self.showPermissionExplanationAlert(completion: completion)
            default:
                completion(false)
            }
        }
    }
    
    /// Requests permission from the system and monitors the result
    private func requestPermissionFromSystem(completion: @escaping (Bool) -> Void) {
        if isTestEnvironment { completion(false); return }
        // Request permission with system prompt
        let checkOptionPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [checkOptionPrompt: true] as CFDictionary
        
        // This call will show the system permission dialog
        let _ = AXIsProcessTrustedWithOptions(options)
        
        // Monitor permission status with periodic checks
        monitorPermissionStatus(completion: completion)
    }
    
    /// Monitors permission status after a system request
    private func monitorPermissionStatus(completion: @escaping (Bool) -> Void) {
        if isTestEnvironment { completion(false); return }
        var checkCount = 0
        let maxChecks = 60 // Check for up to 30 seconds (60 * 0.5s) - users might need time to navigate
        
        func checkStatus() {
            checkCount += 1
            
            if checkPermission() {
                // Permission granted
                Task { @MainActor in
                    self.showPermissionGrantedConfirmation()
                    completion(true)
                }
                return
            }
            
            if checkCount >= maxChecks {
                // Timeout - show helpful message and assume permission was denied
                Task { @MainActor in
                    self.showPermissionTimeoutMessage()
                    completion(false)
                }
                return
            }
            
            // Check again after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                checkStatus()
            }
        }
        
        // Start checking after initial delay to let system dialog appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            checkStatus()
        }
    }
    
    /// Shows confirmation when permission is successfully granted
    private func showPermissionGrantedConfirmation() {
        if isTestEnvironment { return }
        let alert = NSAlert()
        alert.messageText = "SmartPaste Enabled!"
        alert.informativeText = """
        ✅ Accessibility permission has been granted successfully.
        
        SmartPaste is now enabled and will automatically paste transcribed text into your applications.
        
        You can disable SmartPaste anytime in VoiceFlow's Settings if you prefer manual control.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Great!")
        alert.runModal()
    }
    
    /// Shows helpful message when permission request times out
    private func showPermissionTimeoutMessage() {
        if isTestEnvironment { return }
        let alert = NSAlert()
        alert.messageText = "Permission Setup Incomplete"
        alert.informativeText = """
        The accessibility permission setup didn't complete within the expected timeframe.
        
        This might happen if:
        • System Settings was closed without making changes
        • The permission was granted but needs a moment to take effect
        • There was an issue with the system settings dialog
        
        💡 What to do next:
        • Try using SmartPaste - it might work now
        • Use Settings → Show Manual Instructions to set it up manually
        • Restart VoiceFlow if the permission still doesn't work
        
        You can always paste transcribed text manually using ⌘V.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Show Manual Instructions")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            showManualPermissionInstructions()
        }
    }
    
    /// Shows detailed education about Accessibility permissions in macOS
    private func showAccessibilityPermissionEducation() {
        if isTestEnvironment { return }
        Task { @MainActor in
            let alert = NSAlert()
            alert.messageText = "Understanding macOS Accessibility Permissions"
            alert.informativeText = """
            🛡️ What Are Accessibility Permissions?
            
            Accessibility permissions in macOS allow assistive technologies and automation tools to interact with other applications. This is the same permission used by:
            • Screen readers for visually impaired users
            • Voice control software
            • Automation tools like Keyboard Maestro
            • Text expanders and productivity apps
            
            🔍 Why VoiceFlow Needs This Permission:
            
            VoiceFlow needs to send a simple "paste" command (equivalent to pressing ⌘V) to place transcribed text in the right location. Without this permission, you'd need to manually:
            1. Remember which app you were using
            2. Switch back to that app
            3. Find the right text field
            4. Press ⌘V yourself
            
            🔒 Security Safeguards:
            
            • VoiceFlow is sandboxed and can't access other app's data
            • It only sends paste commands, never reads content
            • All permissions are revocable in System Settings
            • You maintain full control over when recordings happen
            
            This permission makes voice transcription seamless while maintaining your privacy and security.
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "I Understand")
            alert.runModal()
        }
    }
    
    /// Shows an alert with instructions for manually enabling permission
    func showManualPermissionInstructions() {
        Task { @MainActor in
            let alert = NSAlert()
            alert.messageText = "Enable Accessibility Permission"
            alert.informativeText = """
            To enable SmartPaste functionality:
            
            1. Open System Settings (click "Open Settings" below)
            2. Go to Privacy & Security → Accessibility
            3. Find VoiceFlow in the list
            4. Toggle the switch to enable it
            5. Return to VoiceFlow
            
            If VoiceFlow isn't in the list, you may need to add it manually using the "+" button.
            
            💡 Troubleshooting:
            • If the toggle appears grayed out, click the lock icon and enter your password
            • If VoiceFlow doesn't appear in the list, try restarting VoiceFlow
            • You may need to remove and re-add VoiceFlow if it's not working
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.openAccessibilitySystemSettings()
            }
        }
    }
    
    /// Opens System Settings to the Accessibility section
    private func openAccessibilitySystemSettings() {
        if isTestEnvironment { return }
        // Try modern URL scheme first (macOS 13+)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            if NSWorkspace.shared.open(url) {
                return
            }
        }
        
        // Fallback to general Privacy & Security settings
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Returns a user-friendly status message for the current permission state
    var permissionStatusMessage: String {
        if checkPermission() {
            return "✅ Accessibility permission granted - SmartPaste is enabled"
        } else {
            return "⚠️ Accessibility permission required for SmartPaste functionality"
        }
    }
    
    /// Returns detailed status information for debugging and user support
    var detailedPermissionStatus: (isGranted: Bool, statusMessage: String, troubleshootingInfo: String?) {
        let isGranted = checkPermission()
        
        if isGranted {
            return (
                isGranted: true,
                statusMessage: "Accessibility permission is properly configured",
                troubleshootingInfo: nil
            )
        } else {
            return (
                isGranted: false,
                statusMessage: "Accessibility permission is not granted",
                troubleshootingInfo: """
                To enable SmartPaste:
                1. Open System Settings → Privacy & Security → Accessibility
                2. Add VoiceFlow to the list (using + button if needed)
                3. Toggle the switch to enable VoiceFlow
                4. Restart VoiceFlow if needed
                """
            )
        }
    }
    
    /// Handles errors that occur during permission requests
    func handlePermissionError(_ error: Error) {
        Task { @MainActor in
            let alert = NSAlert()
            alert.messageText = "Permission Request Error"
            alert.informativeText = """
            An error occurred while requesting Accessibility permission:
            
            \(error.localizedDescription)
            
            You can still enable SmartPaste manually:
            1. Open System Settings
            2. Go to Privacy & Security → Accessibility
            3. Add VoiceFlow and enable it
            
            Or continue using VoiceFlow without SmartPaste - transcribed text will be copied to your clipboard for manual pasting.
            """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Continue Without SmartPaste")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.openAccessibilitySystemSettings()
            }
        }
    }
    
    /// Shows a denial message when user explicitly declines permission
    func showPermissionDeniedMessage() {
        Task { @MainActor in
            let alert = NSAlert()
            alert.messageText = "SmartPaste Disabled"
            alert.informativeText = """
            VoiceFlow will continue to work without SmartPaste functionality.
            
            Transcribed text will be copied to your clipboard, and you can paste it manually using ⌘V.
            
            You can enable SmartPaste anytime in VoiceFlow Settings → General → Accessibility Permissions.
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
