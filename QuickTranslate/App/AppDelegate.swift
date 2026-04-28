import AppKit
import SwiftUI
import Combine
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotkeyManager: HotkeyManager!
    private var ocrHotkeyManager: HotkeyManager!
    private var clipboardHotkeyManager: HotkeyManager!
    private var translationPanel: TranslationPanel!
    private var screenshotOverlay: ScreenshotOverlayWindow?
    private var settingsWindow: NSWindow?
    private var clipboardWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private weak var engineMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        checkAccessibilityPermission()
        translationPanel = TranslationPanel()
        _ = ClipboardHistoryManager.shared  // 启动剪贴板监听

        let settings = SettingsManager.shared

        // 划词翻译快捷键
        hotkeyManager = HotkeyManager(id: 1,
            keyCode: { settings.hotkeyCode },
            modifiers: { settings.hotkeyModifiers }) { [weak self] in
            self?.handleHotkey()
        }
        hotkeyManager.register()

        // 截图翻译快捷键
        ocrHotkeyManager = HotkeyManager(id: 2,
            keyCode: { settings.ocrHotkeyCode },
            modifiers: { settings.ocrHotkeyModifiers }) { [weak self] in
            self?.handleOCRHotkey()
        }
        ocrHotkeyManager.register()

        // 剪贴板历史快捷键
        clipboardHotkeyManager = HotkeyManager(id: 3,
            keyCode: { settings.clipboardHotkeyCode },
            modifiers: { settings.clipboardHotkeyModifiers }) { [weak self] in
            self?.openClipboardHistory()
        }
        clipboardHotkeyManager.register()

        // 设置变化时重新注册
        Publishers.CombineLatest(settings.$hotkeyCode, settings.$hotkeyModifiers)
            .dropFirst()
            .sink { [weak self] _, _ in self?.hotkeyManager.reregister() }
            .store(in: &cancellables)

        Publishers.CombineLatest(settings.$ocrHotkeyCode, settings.$ocrHotkeyModifiers)
            .dropFirst()
            .sink { [weak self] _, _ in self?.ocrHotkeyManager.reregister() }
            .store(in: &cancellables)

        Publishers.CombineLatest(settings.$clipboardHotkeyCode, settings.$clipboardHotkeyModifiers)
            .dropFirst()
            .sink { [weak self] _, _ in self?.clipboardHotkeyManager.reregister() }
            .store(in: &cancellables)

        // 菜单栏引擎名称跟随设置变化
        settings.$selectedEngine
            .sink { [weak self] engine in self?.engineMenuItem?.title = "引擎：\(engine.displayName)" }
            .store(in: &cancellables)
    }

    // MARK: - 状态栏

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "QuickTranslate")
        }

        let menu = NSMenu()

        let engineItem = NSMenuItem(title: "引擎：\(SettingsManager.shared.selectedEngine.displayName)", action: nil, keyEquivalent: "")
        engineItem.isEnabled = false
        menu.addItem(engineItem)
        engineMenuItem = engineItem

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "翻译剪贴板", action: #selector(translateClipboard), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "剪贴板历史", action: #selector(openClipboardHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "偏好设置...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出 QuickTranslate", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    // MARK: - 权限检查

    private func checkAccessibilityPermission() {
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }

    private func hasScreenRecordingPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    private func requestScreenRecordingPermission() {
        CGRequestScreenCaptureAccess()
    }

    // MARK: - 划词翻译

    @objc private func handleHotkey() {
        Task { @MainActor in
            let text = await TextGrabber.grab()
            let mouseLocation = NSEvent.mouseLocation
            if text.isEmpty {
                translationPanel.showError("请先选中要翻译的文字", near: mouseLocation)
            } else {
                translationPanel.show(text: text, near: mouseLocation)
            }
        }
    }

    @objc @MainActor private func translateClipboard() {
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        guard !text.isEmpty else { return }
        translationPanel.show(text: text, near: NSEvent.mouseLocation)
    }

    // MARK: - 截图翻译

    @objc private func handleOCRHotkey() {
        Task { @MainActor in
            guard hasScreenRecordingPermission() else {
                // 弹出系统授权对话框并注册到隐私设置列表
                requestScreenRecordingPermission()
                translationPanel.showError("请在弹出的对话框中允许屏幕录制，然后重试", near: NSEvent.mouseLocation)
                return
            }

            let overlay = ScreenshotOverlayWindow()
            screenshotOverlay = overlay
            overlay.onCapture = { [weak self] image in
                Task { @MainActor in
                    await self?.performOCR(image: image)
                }
            }
            overlay.show()
        }
    }

    @MainActor private func performOCR(image: NSImage) async {
        let near = NSEvent.mouseLocation
        do {
            let text = try await OCRManager.recognizeText(in: image)
            translationPanel.show(text: text, near: near)
        } catch {
            translationPanel.showError(error.localizedDescription, near: near)
        }
    }

    // MARK: - 剪贴板历史窗口

    @objc private func openClipboardHistory() {
        if clipboardWindow == nil {
            let hosting = NSHostingController(rootView: ClipboardHistoryView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "剪贴板历史"
            window.styleMask = [.titled, .closable, .resizable]
            window.setContentSize(NSSize(width: 380, height: 480))
            window.minSize = NSSize(width: 300, height: 300)
            window.maxSize = NSSize(width: 600, height: 800)
            window.delegate = self
            clipboardWindow = window
        }
        clipboardWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - 设置窗口

    @objc private func openSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "偏好设置"
            window.setContentSize(NSSize(width: 440, height: 268))
            window.styleMask = [.titled, .closable]
            window.delegate = self
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === settingsWindow {
            settingsWindow = nil
        }
        if (notification.object as? NSWindow) === clipboardWindow {
            clipboardWindow = nil
        }
    }
}
