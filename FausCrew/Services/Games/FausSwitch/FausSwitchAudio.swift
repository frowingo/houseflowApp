import AVFoundation
import FausCrewCore
import UIKit

/// Faus Switch sound: a looping background track during the race, a short "bloop"
/// for the player's own gravity flips (rising toward the ceiling, falling toward the
/// floor) and a swirling "vwoop" when the player's robot goes through a portal. Effects are decoded once into `AVAudioEngine` buffers before the race,
/// so a tap only schedules a buffer on an already-running player node and never stalls
/// the frame. The session is `.ambient`, so it mixes with other apps' audio and follows the
/// silent switch. Music and effects are switched separately (two HUD buttons), and
/// both choices are remembered. Assets are data sets in the catalog, rendered by
/// `Documents/Games/fausSwitchAudioSynth.py`.
@MainActor
final class FausSwitchAudio {
    /// The flip sounds' switch (the key the single sound switch used before).
    private static let effectsKey = "faus_switch_sound_enabled"
    private static let musicKey = "faus_switch_music_enabled"
    private static let musicVolume: Float = 0.34
    private static let duckedVolume: Float = 0.12
    private static let flipVolume: Float = 0.62
    private static let portalVolume: Float = 0.7

    private(set) var isEffectsEnabled: Bool
    private(set) var isMusicEnabled: Bool
    private let userDefaults: UserDefaults
    private var music: AVAudioPlayer?
    private let engine = AVAudioEngine()
    private var flipNodes: [AVAudioPlayerNode] = []
    /// Three slightly different pitches per direction, so quick flips do not repeat.
    private var flipBuffers: [FausSwitchGravity: [AVAudioPCMBuffer]] = [:]
    private var portalBuffer: AVAudioPCMBuffer?
    private var nextNode = 0
    private var nextVariant = 0
    private var isMusicWanted = false
    private var isMusicPaused = false
    private var isDucked = false
    private var isSessionActive = false

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let effects = userDefaults.object(forKey: Self.effectsKey) as? Bool ?? true
        isEffectsEnabled = effects
        // Until music has its own choice it follows the old single switch.
        isMusicEnabled = userDefaults.object(forKey: Self.musicKey) as? Bool ?? effects
    }

    /// Only the robot's effects (flips, portals); the music keeps playing.
    func setEffectsEnabled(_ enabled: Bool) {
        guard enabled != isEffectsEnabled else { return }
        isEffectsEnabled = enabled
        userDefaults.set(enabled, forKey: Self.effectsKey)
        if enabled { prepareEffects() }
    }

    /// Only the background track; effects are unaffected.
    func setMusicEnabled(_ enabled: Bool) {
        guard enabled != isMusicEnabled else { return }
        isMusicEnabled = enabled
        userDefaults.set(enabled, forKey: Self.musicKey)
        if enabled {
            if isMusicWanted { playMusic(fromStart: false) }
        } else {
            music?.pause()
        }
    }

    // MARK: - Music

    /// From the race countdown on; restarts the loop for a new race.
    func startMusic() {
        isMusicWanted = true
        isMusicPaused = false
        isDucked = false
        playMusic(fromStart: true)
        prepareEffects()
    }

    func stopMusic() {
        isMusicWanted = false
        isMusicPaused = false
        guard let music, music.isPlaying else { return }
        music.setVolume(0, fadeDuration: 0.35)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard let self, !self.isMusicWanted else { return }
            self.music?.stop()
            self.music?.currentTime = 0
        }
    }

    /// Pause (demo pause or the app leaving the foreground) keeps the loop position.
    func setMusicPaused(_ paused: Bool) {
        guard isMusicWanted, paused != isMusicPaused else { return }
        isMusicPaused = paused
        if paused { music?.pause() } else { playMusic(fromStart: false) }
    }

    /// Quieter under result panels and notices.
    func setMusicDucked(_ ducked: Bool) {
        guard ducked != isDucked else { return }
        isDucked = ducked
        music?.setVolume(ducked ? Self.duckedVolume : Self.musicVolume, fadeDuration: 0.3)
    }

    private func playMusic(fromStart: Bool) {
        guard isMusicEnabled, !isMusicPaused, activateSession() else { return }
        if music == nil {
            music = Self.player(named: "FausSwitchMusic")
            music?.numberOfLoops = -1
        }
        guard let music else { return }
        if fromStart { music.currentTime = 0 }
        music.volume = 0
        music.play()
        music.setVolume(isDucked ? Self.duckedVolume : Self.musicVolume, fadeDuration: fromStart ? 0.6 : 0.25)
    }

    // MARK: - Effects

    /// The player's accepted flip, toward `gravity`'s rail. Only schedules a decoded
    /// buffer; nothing here loads, decodes or starts audio hardware.
    func playFlip(toward gravity: FausSwitchGravity) {
        guard isEffectsEnabled, engine.isRunning, !flipNodes.isEmpty,
              let variants = flipBuffers[gravity], !variants.isEmpty else { return }
        let buffer = variants[nextVariant % variants.count]
        nextVariant += 1
        schedule(buffer, volume: Self.flipVolume)
    }

    /// The player's robot went through a portal.
    func playPortal() {
        guard isEffectsEnabled, engine.isRunning, !flipNodes.isEmpty, let portalBuffer else { return }
        schedule(portalBuffer, volume: Self.portalVolume)
    }

    private func schedule(_ buffer: AVAudioPCMBuffer, volume: Float) {
        let node = flipNodes[nextNode % flipNodes.count]
        nextNode += 1
        node.volume = volume
        node.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !node.isPlaying { node.play() }
    }

    /// Decodes the effects and starts the engine; called at the race countdown,
    /// while the course is still.
    func prepareEffects() {
        guard isEffectsEnabled, activateSession() else { return }
        if flipBuffers.isEmpty {
            for (gravity, name) in [(FausSwitchGravity.up, "FausSwitchFlipUp"), (.down, "FausSwitchFlipDown")] {
                guard let source = Self.buffer(named: name) else { continue }
                flipBuffers[gravity] = [0.95, 1.0, 1.06].compactMap { Self.resampled(source, pitch: $0) }
            }
        }
        // Same format as the flips (32 kHz mono), so it shares their player nodes.
        if portalBuffer == nil { portalBuffer = Self.buffer(named: "FausSwitchPortal") }
        guard let format = flipBuffers.values.first?.first?.format else { return }
        if flipNodes.isEmpty {
            for _ in 0..<4 {
                let node = AVAudioPlayerNode()
                engine.attach(node)
                engine.connect(node, to: engine.mainMixerNode, format: format)
                flipNodes.append(node)
            }
        }
        guard !engine.isRunning else { return }
        engine.prepare()
        do {
            try engine.start()
            flipNodes.forEach { $0.play() }
        } catch {
            return
        }
    }

    private static func buffer(named name: String) -> AVAudioPCMBuffer? {
        guard let asset = NSDataAsset(name: name) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).caf")
        do {
            try asset.data.write(to: url, options: .atomic)
            let file = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                frameCapacity: AVAudioFrameCount(file.length)) else { return nil }
            try file.read(into: buffer)
            return buffer
        } catch {
            return nil
        }
    }

    /// A pitch variant by linear resampling (higher pitch, shorter sound).
    private static func resampled(_ source: AVAudioPCMBuffer, pitch: Double) -> AVAudioPCMBuffer? {
        guard pitch != 1 else { return source }
        guard let input = source.floatChannelData else { return nil }
        let inputFrames = Int(source.frameLength)
        let outputFrames = max(1, Int(Double(inputFrames) / pitch))
        guard let output = AVAudioPCMBuffer(pcmFormat: source.format, frameCapacity: AVAudioFrameCount(outputFrames)),
              let target = output.floatChannelData else { return nil }
        for channel in 0..<Int(source.format.channelCount) {
            for frame in 0..<outputFrames {
                let position = Double(frame) * pitch
                let index = min(inputFrames - 1, Int(position))
                let next = min(inputFrames - 1, index + 1)
                let fraction = Float(position - Double(index))
                target[channel][frame] = input[channel][index] * (1 - fraction) + input[channel][next] * fraction
            }
        }
        output.frameLength = AVAudioFrameCount(outputFrames)
        return output
    }

    // MARK: - Session

    private func activateSession() -> Bool {
        guard !isSessionActive else { return true }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            isSessionActive = true
        } catch {
            isSessionActive = false
        }
        return isSessionActive
    }

    private static func player(named name: String) -> AVAudioPlayer? {
        guard let asset = NSDataAsset(name: name) else { return nil }
        return try? AVAudioPlayer(data: asset.data, fileTypeHint: AVFileType.caf.rawValue)
    }
}
