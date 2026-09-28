import AppKit

@MainActor
enum PetSoundPlayer {
    /// Plays a built-in system sound. Pico does not bundle audio files.
    static func play(_ event: PetSoundEvent, volume: Double) {
        let sound = NSSound(named: NSSound.Name(event.systemSoundName))
        sound?.volume = Float(min(1, max(0, volume)))
        sound?.play()
    }
}
