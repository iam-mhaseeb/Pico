import Foundation
import FoundationModels

enum ScreenTools {
    static func makeTools() -> [any Tool] {
        [
            LookAtScreenTool(),
            ClickElementTool(),
            TypeTextTool(),
            PressKeyTool(),
            ClickAtTool()
        ]
    }
}

private func screenAgent() async -> ScreenAgent? {
    await ScreenRuntime.agent
}

struct LookAtScreenTool: Tool {
    let name = "lookAtScreen"
    let description = """
    Capture what is currently on the user's Mac (the app they were using before Ask Pico). \
    Call this when the user asks what is on screen, to refresh after an action, \
    or before clicking something you cannot already see in the screen context. \
    Do not call it for ordinary chat.
    """

    @Generable
    struct Arguments {
        @Guide(description: "Optional hint about what to look for. Pass an empty string if none.")
        var focus: String
    }

    func call(arguments: Arguments) async throws -> String {
        guard let agent = await screenAgent() else {
            return "Screen tools are not available."
        }
        return await agent.look(focus: arguments.focus)
    }
}

struct ClickElementTool: Tool {
    let name = "clickElement"
    let description = """
    Click or press a UI element from the accessibility list. Prefer this over clickAt. \
    Pass the element title or its #id (for example Submit or #12).
    """

    @Generable
    struct Arguments {
        @Guide(description: "Element title or #id from the latest screen snapshot.")
        var target: String
    }

    func call(arguments: Arguments) async throws -> String {
        guard let agent = await screenAgent() else {
            return "Screen tools are not available."
        }
        return await agent.clickElement(target: arguments.target)
    }
}

struct TypeTextTool: Tool {
    let name = "typeText"
    let description = """
    Type text into a field. Optionally focus a named field first. \
    Never type passwords or into secure fields.
    """

    @Generable
    struct Arguments {
        @Guide(description: "The text to type.")
        var text: String
        @Guide(description: "Field title or #id to focus first. Empty string uses the current focus.")
        var field: String
    }

    func call(arguments: Arguments) async throws -> String {
        guard let agent = await screenAgent() else {
            return "Screen tools are not available."
        }
        return await agent.typeText(arguments.text, field: arguments.field)
    }
}

struct PressKeyTool: Tool {
    let name = "pressKey"
    let description = """
    Press a key or shortcut in the target app, such as return, tab, escape, or command+c.
    """

    @Generable
    struct Arguments {
        @Guide(description: "Key spec like return, tab, escape, or command+shift+t.")
        var key: String
    }

    func call(arguments: Arguments) async throws -> String {
        guard let agent = await screenAgent() else {
            return "Screen tools are not available."
        }
        return await agent.pressKey(arguments.key)
    }
}

struct ClickAtTool: Tool {
    let name = "clickAt"
    let description = """
    Click a point on the captured display using normalized coordinates from OCR boxes \
    (x and y from 0 to 1, origin top-left). Use only when no named accessibility element fits.
    """

    @Generable
    struct Arguments {
        @Guide(description: "Horizontal position from 0 (left) to 1 (right).")
        var x: Double
        @Guide(description: "Vertical position from 0 (top) to 1 (bottom).")
        var y: Double
    }

    func call(arguments: Arguments) async throws -> String {
        guard let agent = await screenAgent() else {
            return "Screen tools are not available."
        }
        return await agent.clickAt(x: arguments.x, y: arguments.y)
    }
}
