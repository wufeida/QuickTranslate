import AppKit
import ApplicationServices

enum TextGrabber {
    static func grab() async -> String {
        // 优先：通过 Accessibility API 直接读取选中文字，不碰剪贴板
        if AXIsProcessTrusted(), let text = selectedTextViaAX(), !text.isEmpty {
            return text
        }
        // 降级：模拟 Cmd+C（适用于不支持 AX 的 app）
        return await grabViaClipboard()
    }

    // MARK: - AX 直读

    private static func selectedTextViaAX() -> String? {
        let system = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
                system,
                kAXFocusedUIElementAttribute as CFString,
                &focusedElement) == .success,
              let element = focusedElement else { return nil }

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
                element as! AXUIElement,
                kAXSelectedTextAttribute as CFString,
                &value) == .success,
              let text = value as? String,
              !text.isEmpty else { return nil }

        return text
    }

    // MARK: - Cmd+C 降级

    private static func grabViaClipboard() async -> String {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)
        let previousChangeCount = pasteboard.changeCount

        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags   = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        var changed = false
        for _ in 0..<20 {
            try? await Task.sleep(nanoseconds: 50_000_000)
            if pasteboard.changeCount != previousChangeCount {
                changed = true
                break
            }
        }

        guard changed else { return "" }

        let grabbed = pasteboard.string(forType: .string) ?? ""

        // 恢复原剪贴板
        pasteboard.clearContents()
        if let prev = previousContents {
            pasteboard.setString(prev, forType: .string)
        }

        return grabbed
    }
}
