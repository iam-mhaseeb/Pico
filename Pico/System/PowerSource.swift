import Foundation
import IOKit.ps

enum PowerSource {
    static func isOnBattery() -> Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return false }
        guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() else {
            return false
        }
        let listed = sources as NSArray
        for index in 0..<listed.count {
            guard let source = listed[index] as? CFTypeRef else { continue }
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue()
                as? [String: Any]
            else { continue }
            if isBatteryPower(description[kIOPSPowerSourceStateKey] as? String) {
                return true
            }
        }
        return false
    }

    static func isBatteryPower(_ state: String?) -> Bool {
        state == kIOPSBatteryPowerValue
    }
}
