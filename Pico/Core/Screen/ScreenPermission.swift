import CoreGraphics
import Foundation

protocol ScreenPermissionChecking: AnyObject {
    var hasScreenRecording: Bool { get }
    /// Prompts the user if needed. Returns the post-prompt state (may still be false).
    @discardableResult
    func requestScreenRecording() -> Bool
}

final class SystemScreenPermission: ScreenPermissionChecking, @unchecked Sendable {
    var hasScreenRecording: Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    func requestScreenRecording() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        return CGRequestScreenCaptureAccess()
    }
}
