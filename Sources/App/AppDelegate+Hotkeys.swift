import AppKit
import os.log

internal extension AppDelegate {
    func configureShortcutMonitors() {
        pressAndHoldMonitor?.stop()
        pressAndHoldMonitor = nil
        isHoldRecordingActive = false

        let newConfiguration = PressAndHoldSettings.configuration()
        pressAndHoldConfiguration = newConfiguration

        guard newConfiguration.enabled else { return }

        let keyUpHandler: (() -> Void)? = (newConfiguration.mode == .hold) ? { [weak self] in
            self?.handlePressAndHoldKeyUp()
        } : nil

        let monitor = PressAndHoldKeyMonitor(
            configuration: newConfiguration,
            keyDownHandler: { [weak self] in
                self?.handlePressAndHoldKeyDown()
            },
            keyUpHandler: keyUpHandler
        )

        pressAndHoldMonitor = monitor
        monitor.start()
    }

    private func handlePressAndHoldKeyDown() {
        switch pressAndHoldConfiguration.mode {
        case .hold:
            startRecordingFromPressAndHold()
        case .toggle:
            handleHotkey(source: .pressAndHold)
        }
    }

    private func handlePressAndHoldKeyUp() {
        guard pressAndHoldConfiguration.mode == .hold else { return }
        stopRecordingFromPressAndHold()
    }

    private func startRecordingFromPressAndHold() {
        guard let recorder = audioRecorder else { return }

        if recorder.isRecording {
            isHoldRecordingActive = true
            return
        }

        if !recorder.hasPermission {
            showRecordingWindowForProcessing()
            return
        }

        if recorder.startRecording() {
            isHoldRecordingActive = true
            updateMenuBarIcon(isRecording: true)
            SoundManager().playRecordingStartSound()
        } else {
            isHoldRecordingActive = false
            showRecordingWindowForProcessing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    NotificationCenter.default.post(
                        name: .recordingStartFailed,
                        object: nil
                    )
                }
            }
        }
    }

    private func stopRecordingFromPressAndHold() {
        guard isHoldRecordingActive else { return }
        guard let recorder = audioRecorder, recorder.isRecording else {
            isHoldRecordingActive = false
            return
        }

        isHoldRecordingActive = false
        updateMenuBarIcon(isRecording: false)

        showRecordingWindowForProcessing {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NotificationCenter.default.post(name: .spaceKeyPressed, object: nil)
            }
        }
    }

    func handleHotkey(source: HotkeyTriggerSource) {
        if source == .standardHotkey && pressAndHoldConfiguration.enabled {
            return
        }

        let immediateRecording = UserDefaults.standard.bool(forKey: "immediateRecording")

        if immediateRecording {
            guard let recorder = audioRecorder else {
                Logger.app.error("AudioRecorder not available for immediate recording")
                toggleRecordWindow()
                return
            }

            if recorder.isRecording {
                updateMenuBarIcon(isRecording: false)
                if recordingWindow == nil || recordingWindow?.isVisible == false {
                    toggleRecordWindow()
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    NotificationCenter.default.post(name: .spaceKeyPressed, object: nil)
                }
            } else {
                if !recorder.hasPermission {
                    toggleRecordWindow()
                    return
                }

                if recorder.startRecording() {
                    updateMenuBarIcon(isRecording: true)
                    SoundManager().playRecordingStartSound()
                } else {
                    toggleRecordWindow()
                    NotificationCenter.default.post(
                        name: .recordingStartFailed,
                        object: nil
                    )
                }
            }
        } else {
            toggleRecordWindow()
        }
    }

    private func updateMenuBarIcon(isRecording: Bool) {
        guard let button = statusItem?.button else { return }

        if isRecording {
            startRecordingAnimation()
        } else {
            stopRecordingAnimation()
            button.image = AppSetupHelper.createMenuBarIcon()
        }
    }

    private func startRecordingAnimation() {
        guard let button = statusItem?.button else { return }

        stopRecordingAnimation()

        // Record start time for elapsed time display
        recordingStartTime = Date()

        let iconSize = AppSetupHelper.getAdaptiveMenuBarIconSize()
        let config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .medium)

        // WhisperFlow-inspired indigo/purple color (#6466F1)
        let indigoColor = NSColor(red: 0.39, green: 0.40, blue: 0.95, alpha: 1.0)

        // Create indigo tinted image
        let indigoImage = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Recording")?.withSymbolConfiguration(config)
        indigoImage?.isTemplate = false
        let indigoOutlineImage = indigoImage?.tinted(with: indigoColor)

        // Create dimmed version for pulse effect
        let dimmedIndigoColor = NSColor(red: 0.39, green: 0.40, blue: 0.95, alpha: 0.5)
        let dimmedImage = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Recording")?.withSymbolConfiguration(config)
        dimmedImage?.isTemplate = false
        let dimmedOutlineImage = dimmedImage?.tinted(with: dimmedIndigoColor)

        button.image = indigoOutlineImage

        var isPulseState = true

        let queue = DispatchQueue(label: "com.voiceflow.animation", qos: .background)
        let timer = DispatchSource.makeTimerSource(queue: queue)

        // WhisperFlow-inspired 400ms animation cycle
        timer.schedule(deadline: .now(), repeating: 0.4)

        timer.setEventHandler { [weak button] in
            guard let button = button else { return }

            isPulseState.toggle()

            Task { @MainActor in
                button.image = isPulseState ? indigoOutlineImage : dimmedOutlineImage
            }
        }

        recordingAnimationTimer = timer
        timer.resume()

        // Start elapsed time timer
        startElapsedTimeTimer()
    }

    private func stopRecordingAnimation() {
        recordingAnimationTimer?.cancel()
        recordingAnimationTimer = nil
        stopElapsedTimeTimer()
        recordingStartTime = nil
    }

    private func startElapsedTimeTimer() {
        guard let button = statusItem?.button else { return }

        // Update elapsed time every second
        elapsedTimeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self, weak button] _ in
            guard let self = self, let button = button, let startTime = self.recordingStartTime else { return }

            let elapsed = Date().timeIntervalSince(startTime)
            let minutes = Int(elapsed) / 60
            let seconds = Int(elapsed) % 60
            let timeString = String(format: " %d:%02d", minutes, seconds)

            button.title = timeString
        }
    }

    private func stopElapsedTimeTimer() {
        elapsedTimeTimer?.invalidate()
        elapsedTimeTimer = nil

        // Clear the elapsed time display
        statusItem?.button?.title = ""
    }

    @objc func onRecordingStopped() {
        updateMenuBarIcon(isRecording: false)
    }

    @objc func onTranscriptionStarted() {
        showProcessingState()
    }

    @objc func onTranscriptionCompleted() {
        resetToIdleState()
    }

    private func showProcessingState() {
        guard let button = statusItem?.button else { return }

        stopRecordingAnimation()

        let iconSize = AppSetupHelper.getAdaptiveMenuBarIconSize()
        let config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .medium)

        // WhisperFlow-inspired indigo/purple color for processing
        let indigoColor = NSColor(red: 0.39, green: 0.40, blue: 0.95, alpha: 1.0)

        // Use a spinner/progress icon
        let processingImage = NSImage(systemSymbolName: "circle.dotted", accessibilityDescription: "Processing")?.withSymbolConfiguration(config)
        processingImage?.isTemplate = false
        let tintedImage = processingImage?.tinted(with: indigoColor)

        button.image = tintedImage
        button.title = " ..."

        // Animate the spinner with rotation (simulated with icon swap)
        let queue = DispatchQueue(label: "com.voiceflow.processing", qos: .background)
        let timer = DispatchSource.makeTimerSource(queue: queue)

        // Rotate through different spinner states every 200ms
        let spinnerIcons = ["circle.dotted", "circle.dotted.circle", "circle.dotted.and.circle"]
        var iconIndex = 0

        timer.schedule(deadline: .now(), repeating: 0.2)

        timer.setEventHandler { [weak button] in
            guard let button = button else { return }

            iconIndex = (iconIndex + 1) % spinnerIcons.count
            let nextIcon = NSImage(systemSymbolName: spinnerIcons[iconIndex], accessibilityDescription: "Processing")?.withSymbolConfiguration(config)
            nextIcon?.isTemplate = false
            let nextTintedImage = nextIcon?.tinted(with: indigoColor)

            Task { @MainActor in
                button.image = nextTintedImage
            }
        }

        recordingAnimationTimer = timer
        timer.resume()
    }

    private func resetToIdleState() {
        guard let button = statusItem?.button else { return }

        stopRecordingAnimation()
        button.image = AppSetupHelper.createMenuBarIcon()
        button.title = ""
    }
}
