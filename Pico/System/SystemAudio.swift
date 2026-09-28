import CoreAudio
import Foundation

enum SystemAudio {
    /// True when the default output device is muted or its volume is effectively zero.
    static func isSilent() -> Bool {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &deviceID) == noErr else {
            return false
        }

        var mute: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        address.mSelector = kAudioDevicePropertyMute
        address.mScope = kAudioObjectPropertyScopeOutput
        address.mElement = kAudioObjectPropertyElementMain
        if AudioObjectHasProperty(deviceID, &address),
           AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &mute) == noErr,
           mute != 0 {
            return true
        }

        var volume: Float32 = 1
        size = UInt32(MemoryLayout<Float32>.size)
        address.mSelector = kAudioDevicePropertyVolumeScalar
        if AudioObjectHasProperty(deviceID, &address),
           AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume) == noErr {
            return volume <= 0.001
        }
        return false
    }
}
