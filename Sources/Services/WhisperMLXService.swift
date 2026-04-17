import AudioToolbox
import Foundation
import os.log

internal enum WhisperMLXError: Error, LocalizedError, Equatable {
    case transcriptionFailed(String)
    case modelNotReady

    var errorDescription: String? {
        switch self {
        case .transcriptionFailed(let message):
            return "Whisper MLX transcription failed: \(message)"
        case .modelNotReady:
            return "Whisper MLX model not downloaded. Open Settings \u{25B8} Whisper MLX to download it."
        }
    }
}

internal class WhisperMLXService {
    private let logger = Logger(subsystem: "com.whisp.app", category: "WhisperMLXService")
    private let daemon = MLDaemonManager.shared

    func transcribe(audioFileURL: URL) async throws -> String {
        guard isModelCached() else {
            throw WhisperMLXError.modelNotReady
        }

        // Convert source audio to 16kHz mono WAV for mlx-audio
        let wavURL = try convertToWAV(audioFileURL: audioFileURL)
        defer { try? FileManager.default.removeItem(at: wavURL) }

        return try await transcribeWithDaemon(audioFileURL: wavURL)
    }

    private var selectedRepo: String {
        UserDefaults.standard.string(forKey: AppDefaults.Keys.selectedWhisperMLXModel)
            ?? WhisperMLXModel.largeTurbo.rawValue
    }

    func isModelCached() -> Bool {
        HuggingFaceCache.hasUsableModelSnapshot(for: selectedRepo)
    }

    // MARK: - Audio Conversion

    private func convertToWAV(audioFileURL: URL) throws -> URL {
        let wavURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper_mlx_\(UUID().uuidString).wav")

        var extAudioFile: ExtAudioFileRef?
        var status = ExtAudioFileOpenURL(audioFileURL as CFURL, &extAudioFile)
        guard status == noErr, let srcFile = extAudioFile else {
            throw WhisperMLXError.transcriptionFailed("Failed to open audio file: \(status)")
        }
        defer { ExtAudioFileDispose(srcFile) }

        // Get source format and length
        var srcFormat = AudioStreamBasicDescription()
        var propSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        status = ExtAudioFileGetProperty(srcFile, kExtAudioFileProperty_FileDataFormat, &propSize, &srcFormat)
        guard status == noErr else {
            throw WhisperMLXError.transcriptionFailed("Failed to get audio format: \(status)")
        }

        var lengthFrames: Int64 = 0
        propSize = UInt32(MemoryLayout<Int64>.size)
        status = ExtAudioFileGetProperty(
            srcFile, kExtAudioFileProperty_FileLengthFrames, &propSize, &lengthFrames)
        guard status == noErr else {
            throw WhisperMLXError.transcriptionFailed("Failed to get audio length: \(status)")
        }

        // Target: 16kHz mono float32
        let sampleRate: Float64 = 16000
        var clientFormat = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 32,
            mReserved: 0
        )

        propSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        status = ExtAudioFileSetProperty(
            srcFile, kExtAudioFileProperty_ClientDataFormat, propSize, &clientFormat)
        guard status == noErr else {
            throw WhisperMLXError.transcriptionFailed("Failed to set client format: \(status)")
        }

        // Read all samples
        let duration = Double(lengthFrames) / srcFormat.mSampleRate
        let estimatedFrames = Int(duration * sampleRate + 0.5)
        var samples = [Float]()
        samples.reserveCapacity(estimatedFrames)

        let bufSize = 4096
        var buffer = [Float](repeating: 0, count: bufSize)
        while true {
            var numFrames = UInt32(bufSize)
            let audioBuffer = buffer.withUnsafeMutableBytes { bytes in
                AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(bufSize * 4), mData: bytes.baseAddress)
            }
            var bufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: audioBuffer)
            status = ExtAudioFileRead(srcFile, &numFrames, &bufferList)
            guard status == noErr else {
                throw WhisperMLXError.transcriptionFailed("Failed to read audio: \(status)")
            }
            if numFrames == 0 { break }
            samples.append(contentsOf: buffer[0..<Int(numFrames)])
        }

        // Write WAV file
        try writeWAV(samples: samples, sampleRate: Int(sampleRate), to: wavURL)
        return wavURL
    }

    private func writeWAV(samples: [Float], sampleRate: Int, to url: URL) throws {
        // Convert float32 to int16 for WAV compatibility
        let int16Samples = samples.map { sample -> Int16 in
            let clamped = max(-1.0, min(1.0, sample))
            return Int16(clamped * Float(Int16.max))
        }

        var header = Data()
        let dataSize = int16Samples.count * 2
        let fileSize = 36 + dataSize

        // RIFF header
        header.append(contentsOf: "RIFF".utf8)
        header.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Array($0) })
        header.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        header.append(contentsOf: "fmt ".utf8)
        header.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // PCM
        header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // mono
        header.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate * 2).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) })  // block align
        header.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) })  // bits/sample

        // data chunk
        header.append(contentsOf: "data".utf8)
        header.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })

        // Sample data
        let sampleData = int16Samples.withUnsafeBytes { Data($0) }
        header.append(sampleData)

        try header.write(to: url)
    }

    // MARK: - Daemon

    private func transcribeWithDaemon(audioFileURL: URL) async throws -> String {
        do {
            let text = try await daemon.whisperMLXTranscribe(
                repo: selectedRepo,
                audioPath: audioFileURL.path
            )
            logger.info("Whisper MLX transcription successful")
            return text
        } catch {
            logger.error("Whisper MLX transcription error: \(error.localizedDescription)")
            throw error
        }
    }

    func validateSetup() async throws {
        guard isModelCached() else {
            throw WhisperMLXError.modelNotReady
        }

        do {
            try await daemon.warmup(type: "whisper_mlx", repo: selectedRepo)
        } catch {
            logger.error("Whisper MLX warmup failed: \(error.localizedDescription)")
            throw WhisperMLXError.transcriptionFailed(
                "Whisper MLX daemon unavailable: \(error.localizedDescription)")
        }
    }
}
