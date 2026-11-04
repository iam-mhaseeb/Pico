import AppKit

/// Content for the standard macOS About panel opened from the menu bar.
enum AboutInfo {
    static let authorName = "Muhammad Haseeb"
    static let email = "hello@muhammadhaseeb.me"
    static let websiteDisplay = "muhammadhaseeb.me"
    static let websiteURL = "https://muhammadhaseeb.me"

    static func credits() -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let base: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]

        let result = NSMutableAttributedString(
            string: "A private, on-device writing helper.\nCreated by \(authorName)\n",
            attributes: base
        )
        result.append(link(email, to: "mailto:\(email)", base: base))
        result.append(NSAttributedString(string: "\n", attributes: base))
        result.append(link(websiteDisplay, to: websiteURL, base: base))
        return result
    }

    static func panelOptions() -> [NSApplication.AboutPanelOptionKey: Any] {
        [.credits: credits()]
    }

    private static func link(
        _ text: String,
        to urlString: String,
        base: [NSAttributedString.Key: Any]
    ) -> NSAttributedString {
        var attributes = base
        if let url = URL(string: urlString) {
            attributes[.link] = url
        }
        return NSAttributedString(string: text, attributes: attributes)
    }
}
