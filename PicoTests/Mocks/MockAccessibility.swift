import Foundation
@testable import Pico

@MainActor
final class MockAccessibility: AccessibilityProviding {
    var isTrusted = true
    var selectedTextValue: String?
    var selectedRect: CGRect?
    var setSelectedTextResult = true
    var lastSetText: String?

    func selectedText() -> String? { selectedTextValue }
    func selectedTextRect() -> CGRect? { selectedRect }
    func setSelectedText(_ text: String) -> Bool {
        lastSetText = text
        return setSelectedTextResult
    }
}

@MainActor
final class MockKeyEvents: KeyEventSynthesizing {
    var copyCount = 0
    var pasteCount = 0
    var onCopy: (() -> Void)?

    func copy() {
        copyCount += 1
        onCopy?()
    }

    func paste() {
        pasteCount += 1
    }
}
