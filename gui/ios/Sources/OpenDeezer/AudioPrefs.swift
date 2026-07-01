import Foundation

/// The mobile engine keeps audio settings (quality, gapless, ReplayGain,
/// crossfade) in memory only, so they reset on relaunch. Persist them here and
/// re-apply after login so they survive a reboot.
enum AudioPrefs {
    private static let d = UserDefaults.standard
    private enum K {
        static let quality = "audio.quality"
        static let gapless = "audio.gapless"
        static let replayGain = "audio.replayGain"
        static let crossfade = "audio.crossfadeMs"
    }

    static var quality: Int {
        get { d.object(forKey: K.quality) as? Int ?? Engine.quality() }
        set { d.set(newValue, forKey: K.quality) }
    }
    static var gapless: Bool {
        get { d.object(forKey: K.gapless) as? Bool ?? Engine.gapless() }
        set { d.set(newValue, forKey: K.gapless) }
    }
    static var replayGain: Bool {
        get { d.object(forKey: K.replayGain) as? Bool ?? Engine.replayGain() }
        set { d.set(newValue, forKey: K.replayGain) }
    }
    static var crossfadeMs: Int {
        get { d.object(forKey: K.crossfade) as? Int ?? Engine.crossfadeMS() }
        set { d.set(newValue, forKey: K.crossfade) }
    }

    /// Push the saved settings into the engine. Call once after Init succeeds.
    static func applyOnLaunch() {
        Engine.setQuality(quality)
        Engine.setGapless(gapless)
        Engine.setReplayGain(replayGain)
        Engine.setCrossfadeMS(crossfadeMs)
    }
}
