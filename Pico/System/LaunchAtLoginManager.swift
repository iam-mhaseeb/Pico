import Foundation
import ServiceManagement

enum LaunchAtLoginManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) throws -> Bool {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
        // Store what the system actually reports (e.g. requiresApproval is not "enabled").
        let actual = isEnabled
        UserDefaults.standard.set(actual, forKey: PreferenceKey.launchAtLogin)
        return actual
    }
}
