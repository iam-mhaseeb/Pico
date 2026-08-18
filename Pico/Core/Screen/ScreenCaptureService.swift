import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit

struct CapturedScreen: @unchecked Sendable {
    let image: CGImage
    let displayBounds: CGRect
    let displayID: CGDirectDisplayID
}

enum ScreenCaptureError: LocalizedError, Equatable {
    case notPermitted
    case noDisplay
    case failed

    var errorDescription: String? {
        switch self {
        case .notPermitted:
            return "Pico needs Screen Recording permission to see what’s on your screen."
        case .noDisplay:
            return "I couldn’t find a display to look at."
        case .failed:
            return "I couldn’t capture the screen."
        }
    }
}

@MainActor
protocol ScreenCapturing: AnyObject {
    func captureDisplay(
        displayID: CGDirectDisplayID,
        excludingBundleIDs: Set<String>
    ) async throws -> CapturedScreen
}

@MainActor
final class ScreenCaptureKitCapturer: ScreenCapturing {
    func captureDisplay(
        displayID: CGDirectDisplayID,
        excludingBundleIDs: Set<String>
    ) async throws -> CapturedScreen {
        guard CGPreflightScreenCaptureAccess() else {
            throw ScreenCaptureError.notPermitted
        }

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw ScreenCaptureError.notPermitted
        }

        guard let display = content.displays.first(where: { $0.displayID == displayID }) ?? content.displays.first else {
            throw ScreenCaptureError.noDisplay
        }

        let excluded = content.applications.filter { app in
            excludingBundleIDs.contains(app.bundleIdentifier)
        }
        let filter = SCContentFilter(
            display: display,
            excludingApplications: excluded,
            exceptingWindows: []
        )

        let configuration = SCStreamConfiguration()
        let maxWidth: CGFloat = 1280
        let scale = min(1, maxWidth / CGFloat(display.width))
        configuration.width = max(1, Int(CGFloat(display.width) * scale))
        configuration.height = max(1, Int(CGFloat(display.height) * scale))
        configuration.showsCursor = false

        do {
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            return CapturedScreen(
                image: image,
                displayBounds: CGDisplayBounds(display.displayID),
                displayID: display.displayID
            )
        } catch {
            throw ScreenCaptureError.failed
        }
    }
}
