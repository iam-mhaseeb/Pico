import Foundation
import IOKit.ps

enum PowerSource {
    static func isOnBattery() -> Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return false }
        guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return false
        }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue()
                as? [String: Any]
            else { continue }
            let state = description[kIOPSPowerSourceStateKey] as? String
            if state == kIOPSBatteryPowerValue {
                return true
            }
        }
        return false
    }
}
