import AppKit
import Foundation

enum FrontmostAppHelper {
    static func currentPID() -> pid_t? {
        NSWorkspace.shared.frontmostApplication?.processIdentifier
    }

    @MainActor
    static func activate(pid: pid_t?) async {
        guard let pid,
              let app = NSRunningApplication(processIdentifier: pid),
              !app.isTerminated
        else { return }
        app.activate(options: [.activateIgnoringOtherApps])
        try? await Task.sleep(nanoseconds: 80_000_000)
    }
}
