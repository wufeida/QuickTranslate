import AppKit

class ScreenshotOverlayWindow: NSPanel {
    var onCapture: ((NSImage) -> Void)?

    private let captureScreen: NSScreen
    private var fullScreenImage: CGImage?
    private let selectionView = SelectionView()
    private var keyMonitor: Any?

    init() {
        let screen = NSScreen.screens.first(where: {
            NSMouseInRect(NSEvent.mouseLocation, $0.frame, false)
        }) ?? NSScreen.main!
        captureScreen = screen

        super.init(
            contentRect: screen.frame,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // 在 overlay 显示前截取屏幕内容
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
        fullScreenImage = CGDisplayCreateImage(displayID)

        selectionView.frame = NSRect(origin: .zero, size: screen.frame.size)
        contentView = selectionView

        selectionView.onSelect = { [weak self] rect in self?.finishCapture(rect: rect) }
        selectionView.onCancel = { [weak self] in
            self?.dismiss()
        }
    }

    func show() {
        NSCursor.crosshair.push()
        orderFront(nil)

        // 用全局 monitor 监听 Esc，避免需要成为 key window
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.selectionView.onCancel?() }
        }
    }

    private func dismiss() {
        NSCursor.pop()
        removeKeyMonitor()
        orderOut(nil)
    }

    private func removeKeyMonitor() {
        if let mon = keyMonitor {
            NSEvent.removeMonitor(mon)
            keyMonitor = nil
        }
    }

    private func finishCapture(rect: NSRect) {
        removeKeyMonitor()
        NSCursor.pop()
        orderOut(nil)

        guard let full = fullScreenImage else { return }
        let scale = captureScreen.backingScaleFactor

        // NSView 坐标是左下原点，CGImage 是左上原点，需要翻转 Y
        let deviceRect = CGRect(
            x: rect.minX * scale,
            y: (captureScreen.frame.height - rect.maxY) * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
        guard let cropped = full.cropping(to: deviceRect) else { return }
        onCapture?(NSImage(cgImage: cropped, size: rect.size))
    }
}

// MARK: - 选区视图

private class SelectionView: NSView {
    var onSelect: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: NSPoint = .zero
    private var currentPoint: NSPoint = .zero
    private var isSelecting = false

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.45).setFill()
        bounds.fill()

        if isSelecting {
            let rect = selectionRect()
            guard rect.width > 2, rect.height > 2 else { return }

            // 挖空选区，露出真实屏幕内容
            NSGraphicsContext.current?.cgContext.clear(rect)

            // 蓝色虚线边框
            NSColor.systemBlue.setStroke()
            let path = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
            path.lineWidth = 1.5
            path.setLineDash([4, 2], count: 2, phase: 0)
            path.stroke()

            drawSizeLabel(for: rect)
        } else {
            drawHint()
        }
    }

    private func drawHint() {
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 4
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.7)

        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white.withAlphaComponent(0.9),
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .shadow: shadow,
        ]
        let str = NSAttributedString(string: "拖拽选择截图区域   按 Esc 取消", attributes: attrs)
        let sz = str.size()
        str.draw(at: NSPoint(x: (bounds.width - sz.width) / 2, y: (bounds.height - sz.height) / 2))
    }

    private func drawSizeLabel(for rect: NSRect) {
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
        ]
        let str = NSAttributedString(string: " \(Int(rect.width)) × \(Int(rect.height)) ", attributes: attrs)
        let sz = str.size()
        var origin = NSPoint(x: rect.maxX - sz.width - 2, y: rect.maxY + 5)
        if origin.y + sz.height > bounds.maxY - 4 { origin.y = rect.minY - sz.height - 5 }

        NSColor.systemBlue.withAlphaComponent(0.85).setFill()
        NSBezierPath(roundedRect: NSRect(origin: origin, size: sz), xRadius: 3, yRadius: 3).fill()
        str.draw(at: origin)
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        isSelecting = false
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        isSelecting = true
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        let rect = selectionRect()
        guard rect.width > 5, rect.height > 5 else {
            isSelecting = false
            needsDisplay = true
            return
        }
        onSelect?(rect)
    }

    private func selectionRect() -> NSRect {
        NSRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
    }
}
