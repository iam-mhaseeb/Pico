import CoreGraphics
import Foundation

struct OCRLine: Equatable, Sendable {
    let text: String
    /// Normalized box with origin at the **top-left** of the captured display (0...1).
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    var formatted: String {
        let clipped = String(text.prefix(80)).replacingOccurrences(of: "\n", with: " ")
        return String(
            format: "[%.2f,%.2f,%.2f,%.2f] %@",
            x, y, width, height, clipped
        )
    }
}

struct AXNode: Equatable, Sendable {
    let id: Int
    let role: String
    let title: String
    let value: String?
    let enabled: Bool
    let secure: Bool

    var formatted: String {
        var line = "- \(role) \"\(title)\" #\(id)"
        if let value, !value.isEmpty, !secure {
            let clipped = String(value.prefix(60)).replacingOccurrences(of: "\n", with: " ")
            line += " value=\"\(clipped)\""
        }
        if !enabled { line += " disabled" }
        if secure { line += " secure" }
        return line
    }
}

struct AccessibilitySnapshot: Equatable, Sendable {
    var appName: String
    var pid: pid_t
    var windowTitle: String
    var nodes: [AXNode]

    func description(maxNodes: Int = 100) -> String {
        var lines: [String] = [
            "APP: \(appName) (pid \(pid))",
            "WINDOW: \(windowTitle.isEmpty ? "(none)" : windowTitle)"
        ]
        if nodes.isEmpty {
            lines.append("(no UI elements found)")
        } else {
            lines.append(contentsOf: nodes.prefix(maxNodes).map(\.formatted))
        }
        return lines.joined(separator: "\n")
    }

    func node(matching target: String) -> AXNode? {
        let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("#"), let id = Int(trimmed.dropFirst()) {
            return nodes.first { $0.id == id }
        }
        if let id = Int(trimmed), nodes.contains(where: { $0.id == id }) {
            return nodes.first { $0.id == id }
        }

        let needle = trimmed.lowercased()
        if let exact = nodes.first(where: { $0.title.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return exact
        }
        let contains = nodes.filter { $0.title.lowercased().contains(needle) }
        if contains.count == 1 { return contains[0] }
        if let enabled = contains.first(where: \.enabled) { return enabled }
        return contains.first
    }
}

enum ScreenDescription {
    static let maxCharacters = 6_000

    static func compose(appName: String, ax: String, ocr: String) -> String {
        let body = """
        Frontmost app: \(appName)

        ACCESSIBILITY (prefer these names/ids when clicking):
        \(ax)

        VISIBLE TEXT OCR — boxes are normalized x,y,w,h from the top-left of the display (0–1). Use click_at only when no named element fits:
        \(ocr.isEmpty ? "(no text recognized)" : ocr)
        """
        return truncate(body, limit: maxCharacters)
    }

    static func truncate(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        let index = text.index(text.startIndex, offsetBy: limit)
        return String(text[..<index]) + "\n…"
    }
}

enum ScreenCoordinates {
    /// Convert a top-left normalized point into global Quartz coordinates.
    static func quartzPoint(
        normalizedX: Double,
        normalizedY: Double,
        displayBounds: CGRect
    ) -> CGPoint {
        let x = min(max(normalizedX, 0), 1)
        let y = min(max(normalizedY, 0), 1)
        return CGPoint(
            x: displayBounds.minX + x * displayBounds.width,
            y: displayBounds.minY + y * displayBounds.height
        )
    }
}
