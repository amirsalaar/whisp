import AppKit
import Combine
import SwiftUI

@MainActor
internal final class FloatingMicrophoneDockManager: NSObject {
    static let shared = FloatingMicrophoneDockManager()

    private let viewModel = FloatingMicrophoneDockViewModel()
    private var cancellables = Set<AnyCancellable>()
    private var notificationObservers: [NSObjectProtocol] = []
    private var userDefaultsObserver: NSObjectProtocol?
    private weak var panel: FloatingMicrophoneDockPanel?
    private var windowDelegate: FloatingMicrophoneDockWindowDelegate?
    private var primaryAction: (() -> Void)?
    private var openSettingsAction: (() -> Void)?

    private override init() {
        super.init()
    }

    func configure(
        recorder: AudioRecorder,
        primaryAction: @escaping () -> Void,
        openSettingsAction: @escaping () -> Void
    ) {
        guard !AppEnvironment.isRunningTests else { return }

        self.primaryAction = primaryAction
        self.openSettingsAction = openSettingsAction

        bindRecorder(recorder)
        installNotificationObserversIfNeeded()
        installUserDefaultsObserverIfNeeded()
        updateVisibility()
    }

    func refreshPositionIfNeeded() {
        guard let panel else { return }

        if !clampPanelToVisibleFrame(panel) {
            positionPanel(panel)
        }
    }

    func stop() {
        cancellables.removeAll()

        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()

        if let userDefaultsObserver {
            NotificationCenter.default.removeObserver(userDefaultsObserver)
            self.userDefaultsObserver = nil
        }

        panel?.close()
        panel = nil
        windowDelegate = nil
    }

    private func bindRecorder(_ recorder: AudioRecorder) {
        cancellables.removeAll()

        recorder.$isRecording
            .combineLatest(recorder.$audioLevel, recorder.$hasPermission)
            .receive(on: RunLoop.main)
            .sink { [weak self] isRecording, audioLevel, hasPermission in
                self?.viewModel.applyRecorderState(
                    isRecording: isRecording,
                    audioLevel: audioLevel,
                    hasPermission: hasPermission
                )
            }
            .store(in: &cancellables)
    }

    private func installNotificationObserversIfNeeded() {
        guard notificationObservers.isEmpty else { return }

        let center = NotificationCenter.default
        notificationObservers = [
            center.addObserver(
                forName: .transcriptionStarted,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.viewModel.handleTranscriptionStarted()
                }
            },
            center.addObserver(
                forName: .transcriptionCompleted,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.viewModel.handleTranscriptionCompleted()
                }
            },
        ]
    }

    private func installUserDefaultsObserverIfNeeded() {
        guard userDefaultsObserver == nil else { return }

        userDefaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateVisibility()
            }
        }
    }

    private func updateVisibility() {
        let shouldShow = UserDefaults.standard.bool(forKey: AppDefaults.Keys.floatingMicrophoneDockEnabled)

        guard shouldShow else {
            panel?.orderOut(nil)
            return
        }

        if let panel {
            panel.orderFrontRegardless()
            clampPanelToVisibleFrame(panel)
            return
        }

        showPanel()
    }

    private func showPanel() {
        let dockView = FloatingMicrophoneDockView(
            viewModel: viewModel,
            onPrimaryAction: { [weak self] in
                self?.primaryAction?()
            },
            onSettingsAction: { [weak self] in
                self?.openSettingsAction?()
            }
        )

        let panel = FloatingMicrophoneDockPanel(
            contentRect: NSRect(origin: .zero, size: LayoutMetrics.FloatingDock.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.contentViewController = NSHostingController(rootView: dockView)

        windowDelegate = FloatingMicrophoneDockWindowDelegate(manager: self)
        panel.delegate = windowDelegate

        if !panel.setFrameUsingName(Self.autosaveName) {
            positionPanel(panel)
        }
        panel.setFrameAutosaveName(Self.autosaveName)
        panel.orderFrontRegardless()

        self.panel = panel
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let screen = currentScreen(for: panel) else { return }

        let frame = screen.visibleFrame
        let origin = CGPoint(
            x: frame.maxX - LayoutMetrics.FloatingDock.width - LayoutMetrics.FloatingDock.screenInset,
            y: frame.minY + LayoutMetrics.FloatingDock.screenInset
        )
        panel.setFrameOrigin(origin)
    }

    @discardableResult
    private func clampPanelToVisibleFrame(_ panel: NSPanel) -> Bool {
        guard let screen = currentScreen(for: panel) else { return false }

        let visibleFrame = screen.visibleFrame.insetBy(
            dx: LayoutMetrics.FloatingDock.screenInset / 2,
            dy: LayoutMetrics.FloatingDock.screenInset / 2
        )
        var frame = panel.frame

        let clampedX = min(max(frame.origin.x, visibleFrame.minX), visibleFrame.maxX - frame.width)
        let clampedY = min(max(frame.origin.y, visibleFrame.minY), visibleFrame.maxY - frame.height)

        if clampedX == frame.origin.x && clampedY == frame.origin.y {
            return true
        }

        frame.origin = CGPoint(x: clampedX, y: clampedY)
        panel.setFrame(frame, display: true, animate: false)
        return true
    }

    private func currentScreen(for panel: NSPanel?) -> NSScreen? {
        if let panel {
            let panelCenter = CGPoint(x: panel.frame.midX, y: panel.frame.midY)
            if let matchingScreen = NSScreen.screens.first(where: { $0.frame.contains(panelCenter) }) {
                return matchingScreen
            }
        }

        return NSScreen.main ?? NSScreen.screens.first
    }

    private static let autosaveName = "VoiceFlowFloatingMicrophoneDock"
}

private final class FloatingMicrophoneDockPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class FloatingMicrophoneDockWindowDelegate: NSObject, NSWindowDelegate {
    private weak var manager: FloatingMicrophoneDockManager?

    init(manager: FloatingMicrophoneDockManager) {
        self.manager = manager
        super.init()
    }

    func windowDidMove(_ notification: Notification) {
        manager?.refreshPositionIfNeeded()
    }
}
