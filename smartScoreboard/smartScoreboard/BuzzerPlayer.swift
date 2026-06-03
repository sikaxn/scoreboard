import AVFoundation
import Foundation

enum ScoreboardSoundEvent: String, CaseIterable, Identifiable {
    case general
    case gameClockExpired
    case shotClockExpired
    case chessClockExpired
    case debateSegmentExpired
    case debatePrepExpired
    case hockeyPenaltyExpired

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "General Sample"
        case .gameClockExpired:
            return "Game Clock"
        case .shotClockExpired:
            return "Shot Clock"
        case .chessClockExpired:
            return "Chess Clock"
        case .debateSegmentExpired:
            return "Debate Segment"
        case .debatePrepExpired:
            return "Prep Time"
        case .hockeyPenaltyExpired:
            return "Penalty Timer"
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            return "Default scoreboard sound"
        case .gameClockExpired:
            return "Main clock expiration"
        case .shotClockExpired:
            return "Short possession timer alert"
        case .chessClockExpired:
            return "Side clock expiration"
        case .debateSegmentExpired:
            return "Speech or cross-ex timer"
        case .debatePrepExpired:
            return "Per-side prep timer"
        case .hockeyPenaltyExpired:
            return "Penalty timer release"
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            return "speaker.wave.2"
        case .gameClockExpired:
            return "timer"
        case .shotClockExpired:
            return "timer.circle"
        case .chessClockExpired:
            return "checkerboard.rectangle"
        case .debateSegmentExpired:
            return "quote.bubble"
        case .debatePrepExpired:
            return "hourglass"
        case .hockeyPenaltyExpired:
            return "figure.hockey"
        }
    }
}

enum ScoreboardSoundEffect: Hashable {
    case classicBuzzer
    case arenaHorn
    case whistle
    case hockeySiren
    case softChime
    case debateBell
    case debateDoubleBell
    case shotClockBeep
    case penaltyChirp
}

final class BuzzerPlayer {
    private var audioPlayers: [ScoreboardSoundEffect: AVAudioPlayer] = [:]

    func play(_ effect: ScoreboardSoundEffect = .classicBuzzer) {
        activatePlaybackSessionIfNeeded()
        guard let audioPlayer = player(for: effect) else {
            return
        }

        audioPlayer.stop()
        audioPlayer.currentTime = 0
        audioPlayer.play()
    }

    func stop() {
        for audioPlayer in audioPlayers.values {
            audioPlayer.stop()
            audioPlayer.currentTime = 0
        }
        deactivatePlaybackSessionIfNeeded()
    }

    private func player(for effect: ScoreboardSoundEffect) -> AVAudioPlayer? {
        if let audioPlayer = audioPlayers[effect] {
            return audioPlayer
        }

        guard let audioPlayer = try? AVAudioPlayer(data: Self.waveformData(for: effect)) else {
            return nil
        }

        audioPlayer.volume = 1
        audioPlayer.prepareToPlay()
        audioPlayers[effect] = audioPlayer
        return audioPlayer
    }

    private static func waveformData(for effect: ScoreboardSoundEffect) -> Data {
        switch effect {
        case .classicBuzzer:
            return classicBuzzerWaveformData()
        case .arenaHorn:
            return sequenceWaveformData([
                AudioSegment(duration: 0.78, startFrequency: 176, endFrequency: 176, amplitude: 0.34, waveform: .square, attack: 0.018, release: 0.08, tremoloRate: 4),
                .silence(duration: 0.09),
                AudioSegment(duration: 0.78, startFrequency: 176, endFrequency: 168, amplitude: 0.34, waveform: .square, attack: 0.012, release: 0.16, tremoloRate: 5),
                .silence(duration: 0.06),
                AudioSegment(duration: 0.52, startFrequency: 138, endFrequency: 138, amplitude: 0.30, waveform: .square, attack: 0.012, release: 0.18, tremoloRate: 3)
            ])
        case .whistle:
            return sequenceWaveformData([
                AudioSegment(duration: 0.34, startFrequency: 1_680, endFrequency: 1_980, amplitude: 0.22, waveform: .sine, attack: 0.012, release: 0.035, tremoloRate: 12),
                .silence(duration: 0.045),
                AudioSegment(duration: 0.42, startFrequency: 1_940, endFrequency: 1_760, amplitude: 0.24, waveform: .sine, attack: 0.008, release: 0.06, tremoloRate: 10)
            ])
        case .hockeySiren:
            return sequenceWaveformData([
                AudioSegment(duration: 0.72, startFrequency: 460, endFrequency: 740, amplitude: 0.30, waveform: .triangle, attack: 0.02, release: 0.04, tremoloRate: 7),
                AudioSegment(duration: 0.72, startFrequency: 740, endFrequency: 460, amplitude: 0.30, waveform: .triangle, attack: 0.01, release: 0.04, tremoloRate: 7),
                AudioSegment(duration: 0.72, startFrequency: 460, endFrequency: 760, amplitude: 0.28, waveform: .triangle, attack: 0.01, release: 0.18, tremoloRate: 7)
            ])
        case .softChime:
            return bellWaveformData(strikes: [BellStrike(offset: 0, frequency: 880, amplitude: 0.24, decay: 3.2)], duration: 1.28)
        case .debateBell:
            return bellWaveformData(strikes: [BellStrike(offset: 0, frequency: 660, amplitude: 0.30, decay: 2.7)], duration: 1.45)
        case .debateDoubleBell:
            return bellWaveformData(
                strikes: [
                    BellStrike(offset: 0, frequency: 740, amplitude: 0.24, decay: 3.2),
                    BellStrike(offset: 0.38, frequency: 740, amplitude: 0.24, decay: 3.2)
                ],
                duration: 1.45
            )
        case .shotClockBeep:
            return sequenceWaveformData([
                AudioSegment(duration: 0.15, startFrequency: 1_050, endFrequency: 1_050, amplitude: 0.30, waveform: .square, attack: 0.004, release: 0.025, tremoloRate: nil),
                .silence(duration: 0.08),
                AudioSegment(duration: 0.18, startFrequency: 1_180, endFrequency: 1_180, amplitude: 0.31, waveform: .square, attack: 0.004, release: 0.03, tremoloRate: nil)
            ])
        case .penaltyChirp:
            return sequenceWaveformData([
                AudioSegment(duration: 0.14, startFrequency: 900, endFrequency: 1_240, amplitude: 0.25, waveform: .square, attack: 0.004, release: 0.025, tremoloRate: nil),
                .silence(duration: 0.06),
                AudioSegment(duration: 0.44, startFrequency: 520, endFrequency: 760, amplitude: 0.28, waveform: .triangle, attack: 0.008, release: 0.08, tremoloRate: 9)
            ])
        }
    }

    private static func classicBuzzerWaveformData() -> Data {
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
            appendSample(waveform * amplitude * envelope * pulseEnvelope, to: &pcmData)
        }

        return wavData(
            pcmData: pcmData,
            sampleRate: sampleRate,
            channels: 1,
            bitsPerSample: 16
        )
    }

    private static func sequenceWaveformData(_ segments: [AudioSegment]) -> Data {
        let sampleRate = 44_100
        let sampleCount = segments.reduce(0) { total, segment in
            total + Int(Double(sampleRate) * segment.duration)
        }
        var pcmData = Data(capacity: sampleCount * MemoryLayout<Int16>.size)

        for segment in segments {
            let segmentSampleCount = Int(Double(sampleRate) * segment.duration)
            guard segmentSampleCount > 0 else { continue }

            for sampleIndex in 0..<segmentSampleCount {
                let progress = Double(sampleIndex) / Double(segmentSampleCount)
                let time = Double(sampleIndex) / Double(sampleRate)
                let frequency = segment.startFrequency + ((segment.endFrequency - segment.startFrequency) * progress)
                let envelope = segmentEnvelope(
                    time: time,
                    duration: segment.duration,
                    attack: segment.attack,
                    release: segment.release
                )
                let tremolo = segment.tremoloRate.map { 0.78 + (0.22 * ((sin(2 * .pi * $0 * time) + 1) / 2)) } ?? 1
                let value = segment.waveform.sample(frequency: frequency, time: time) * segment.amplitude * envelope * tremolo
                appendSample(value, to: &pcmData)
            }
        }

        return wavData(
            pcmData: pcmData,
            sampleRate: sampleRate,
            channels: 1,
            bitsPerSample: 16
        )
    }

    private static func bellWaveformData(strikes: [BellStrike], duration: Double) -> Data {
        let sampleRate = 44_100
        let sampleCount = Int(Double(sampleRate) * duration)
        var pcmData = Data(capacity: sampleCount * MemoryLayout<Int16>.size)

        for sampleIndex in 0..<sampleCount {
            let time = Double(sampleIndex) / Double(sampleRate)
            var value = 0.0

            for strike in strikes {
                let age = time - strike.offset
                guard age >= 0 else { continue }

                let attack = min(age / 0.014, 1)
                let decay = exp(-age * strike.decay)
                let shimmer = sin(2 * .pi * strike.frequency * 2.01 * age) * 0.22
                let overtone = sin(2 * .pi * strike.frequency * 1.5 * age) * 0.18
                let base = sin(2 * .pi * strike.frequency * age)
                value += (base + shimmer + overtone) * strike.amplitude * attack * decay
            }

            appendSample(value, to: &pcmData)
        }

        return wavData(
            pcmData: pcmData,
            sampleRate: sampleRate,
            channels: 1,
            bitsPerSample: 16
        )
    }

    private static func segmentEnvelope(
        time: Double,
        duration: Double,
        attack: Double,
        release: Double
    ) -> Double {
        let attackEnvelope = attack > 0 ? min(time / attack, 1) : 1
        let releaseEnvelope = release > 0 ? min((duration - time) / release, 1) : 1
        return max(0, min(attackEnvelope, releaseEnvelope))
    }

    private static func appendSample(_ value: Double, to data: inout Data) {
        let clamped = max(-1.0, min(1.0, value))
        var sample = Int16(clamped * Double(Int16.max))
        data.append(Data(bytes: &sample, count: MemoryLayout<Int16>.size))
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

private struct AudioSegment {
    let duration: Double
    let startFrequency: Double
    let endFrequency: Double
    let amplitude: Double
    let waveform: AudioWaveform
    let attack: Double
    let release: Double
    let tremoloRate: Double?

    static func silence(duration: Double) -> AudioSegment {
        AudioSegment(
            duration: duration,
            startFrequency: 0,
            endFrequency: 0,
            amplitude: 0,
            waveform: .sine,
            attack: 0,
            release: 0,
            tremoloRate: nil
        )
    }
}

private enum AudioWaveform {
    case sine
    case square
    case triangle

    func sample(frequency: Double, time: Double) -> Double {
        guard frequency > 0 else {
            return 0
        }

        switch self {
        case .sine:
            return sin(2 * .pi * frequency * time)
        case .square:
            return sin(2 * .pi * frequency * time) >= 0 ? 1.0 : -1.0
        case .triangle:
            let phase = frequency * time
            return 2 * abs(2 * (phase - floor(phase + 0.5))) - 1
        }
    }
}

private struct BellStrike {
    let offset: Double
    let frequency: Double
    let amplitude: Double
    let decay: Double
}

private extension FixedWidthInteger {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<Self>.size)
    }
}
