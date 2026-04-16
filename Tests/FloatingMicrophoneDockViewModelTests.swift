import XCTest

@testable import VoiceFlow

@MainActor
final class FloatingMicrophoneDockViewModelTests: XCTestCase {
    func testPermissionRequiredWhenRecorderCannotAccessMicrophone() {
        let viewModel = FloatingMicrophoneDockViewModel(successResetDelay: .milliseconds(10))

        viewModel.applyRecorderState(isRecording: false, audioLevel: 0, hasPermission: false)

        XCTAssertEqual(viewModel.status, .permissionRequired)
    }

    func testProcessingStatePersistsAfterRecorderStopsUntilCompletionNotification() {
        let viewModel = FloatingMicrophoneDockViewModel(successResetDelay: .milliseconds(10))

        viewModel.applyRecorderState(isRecording: true, audioLevel: 0.6, hasPermission: true)
        viewModel.handleTranscriptionStarted()
        viewModel.applyRecorderState(isRecording: false, audioLevel: 0, hasPermission: true)

        XCTAssertEqual(viewModel.status, .processing("Transcribing..."))
    }

    func testCompletionShowsSuccessThenReturnsToReady() async {
        let viewModel = FloatingMicrophoneDockViewModel(successResetDelay: .milliseconds(10))

        viewModel.applyRecorderState(isRecording: false, audioLevel: 0, hasPermission: true)
        viewModel.handleTranscriptionStarted()
        viewModel.handleTranscriptionCompleted()

        XCTAssertEqual(viewModel.status, .success)

        try? await Task.sleep(for: .milliseconds(30))

        XCTAssertEqual(viewModel.status, .ready)
    }
}
