import AVFoundation
import Foundation

final class BuzzerPlayer {
    private var audioPlayer: AVAudioPlayer?

    init() {
        audioPlayer = try? AVAudioPlayer(data: Self.buzzerWaveformData())
        audioPlayer?.volume = 1
        audioPlayer?.prepareToPlay()
    }

    func play() {
        activatePlaybackSessionIfNeeded()
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        audioPlayer?.play()
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        deactivatePlaybackSessionIfNeeded()
    }

    private static func buzzerWaveformData() -> Data {
        let sampleRate = 44_100
        let duration = 4.0
        let sampleCount = Int(Double(sampleRate) * duration)
        let amplitude = 0.34
        let fundamental = 184.0
        let attackDuration = 0.015
        let releaseDuration = 0.08
        let pulseRate = 8.0

        var pcmData = Data(capacity: sampleCount * MemoryLayout<Int16>.size)

        for sampleIndex in 0..<sampleCount {
            let time = Double(sampleIndex) / Double(sampleRate)
            let attackEnvelope = min(time / attackDuration, 1)
            let releaseEnvelope = min((duration - time) / releaseDuration, 1)
            let envelope = max(0, min(attackEnvelope, releaseEnvelope))
            let primaryWave = sin(2 * .pi * fundamental * time) >= 0 ? 1.0 : -1.0
            let octaveWave = sin(2 * .pi * fundamental * 2 * time) >= 0 ? 1.0 : -1.0
            let pulseEnvelope = 0.82 + (0.18 * ((sin(2 * .pi * pulseRate * time) + 1) / 2))
            let waveform = (primaryWave * 0.86) + (octaveWave * 0.14)
            let value = max(-1.0, min(1.0, waveform * amplitude * envelope * pulseEnvelope))
            var sample = Int16(value * Double(Int16.max))
            pcmData.append(Data(bytes: &sample, count: MemoryLayout<Int16>.size))
        }

        return wavData(
            pcmData: pcmData,
            sampleRate: sampleRate,
            channels: 1,
            bitsPerSample: 16
        )
    }

    private static func wavData(
        pcmData: Data,
        sampleRate: Int,
        channels: Int,
        bitsPerSample: Int
    ) -> Data {
        let byteRate = sampleRate * channels * bitsPerSample / 8
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = pcmData.count
        let riffChunkSize = 36 + dataSize

        var data = Data()
        data.append("RIFF".data(using: .ascii)!)
        data.append(UInt32(riffChunkSize).littleEndianData)
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        data.append(UInt32(16).littleEndianData)
        data.append(UInt16(1).littleEndianData)
        data.append(UInt16(channels).littleEndianData)
        data.append(UInt32(sampleRate).littleEndianData)
        data.append(UInt32(byteRate).littleEndianData)
        data.append(UInt16(blockAlign).littleEndianData)
        data.append(UInt16(bitsPerSample).littleEndianData)
        data.append("data".data(using: .ascii)!)
        data.append(UInt32(dataSize).littleEndianData)
        data.append(pcmData)
        return data
    }

    private func activatePlaybackSessionIfNeeded() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        #endif
    }

    private func deactivatePlaybackSessionIfNeeded() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
        #endif
    }
}

private extension FixedWidthInteger {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<Self>.size)
    }
}
