import AppKit
import SwiftUI

class TranslationPanel: NSObject {
    private var panel: NSPanel?
    private var monitor: Any?

    @MainActor func show(text: String, near point: NSPoint) {
        close()

        let viewModel = TranslationViewModel(originalText: text)
        let contentView = TranslationView(viewModel: viewModel, onClose: { [weak self] in
            self?.close()
        }, onHeightChange: { [weak self] height in
            self?.resizePanel(to: height)
        })

        let hosting = NSHostingView(rootView: contentView)
        hosting.frame = NSRect(x: 0, y: 0, width: 320, height: 480)
        let initialHeight = min(hosting.fittingSize.height, 480)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: initialHeight),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        hosting.frame = NSRect(x: 0, y: 0, width: 320, height: initialHeight)
        panel.contentView = hosting
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true

        let origin = calculateOrigin(near: point, size: NSSize(width: 320, height: initialHeight))
        panel.setFrameOrigin(origin)

        self.panel = panel
        panel.orderFront(nil)
        panel.alphaValue = 0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 1
        }

        // 点击窗口外关闭
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }

        viewModel.performTranslation()
    }

    @MainActor func showError(_ message: String, near point: NSPoint) {
        close()
        let view = ErrorToastView(message: message, onClose: { [weak self] in self?.close() })
        let size = NSSize(width: 260, height: 52)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: size)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.setFrameOrigin(calculateOrigin(near: point, size: size))

        self.panel = panel
        panel.orderFront(nil)
        panel.alphaValue = 0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 1
        }

        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }

        // 2 秒后自动消失
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.close()
        }
    }

    @MainActor private func resizePanel(to height: CGFloat) {
        guard let panel else { return }
        let newHeight = min(height, 480)
        let oldHeight = panel.frame.height
        guard abs(newHeight - oldHeight) > 1 else { return }
        var frame = panel.frame
        frame.origin.y += oldHeight - newHeight  // 顶部位置不变，向下扩展
        frame.size.height = newHeight
        panel.setFrame(frame, display: true, animate: false)
    }

    @MainActor func close() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
        }
        self.panel = nil
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func calculateOrigin(near point: NSPoint, size: NSSize) -> NSPoint {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main else {
            return point
        }
        let margin: CGFloat = 12
        var x = point.x + margin
        var y = point.y - size.height - margin

        if x + size.width > screen.visibleFrame.maxX {
            x = point.x - size.width - margin
        }
        if y < screen.visibleFrame.minY {
            y = point.y + margin
        }
        return NSPoint(x: x, y: y)
    }
}
