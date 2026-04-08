import AppKit

// Lightweight mock of NSRunningApplication used by PasteManager tests
final class MockRunningApplication: NSRunningApplication {
    var mockIsTerminated: Bool = false
    var mockIsActive: Bool = true
    var mockActivationCount: Int = 0

    override var isTerminated: Bool { mockIsTerminated }
    override var isActive: Bool { mockIsActive }

    override func activate(options: NSApplication.ActivationOptions = []) -> Bool {
        mockActivationCount += 1
        return true
    }
}

