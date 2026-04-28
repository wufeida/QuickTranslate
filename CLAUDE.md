# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
# 编译、打包并启动 .app
./build.sh

# 仅编译（不打包）
SDK=$(xcrun --sdk macosx --show-sdk-path)
swiftc -sdk "$SDK" -target arm64-apple-macos13.0 -strict-concurrency=minimal -O \
  -framework Carbon -framework AppKit -framework AVFoundation \
  -framework SwiftUI -framework Combine -framework Vision \
  $(find QuickTranslate -name "*.swift" | sort) -o /tmp/QuickTranslate_bin

# 生成图标（输出到 /tmp/AppIcon.icns）
swift make_icon.swift && iconutil -c icns /tmp/AppIcon.iconset -o /tmp/AppIcon.icns

# 打包 DMG（需先 build.sh 生成 .app）
./make_dmg.sh
```

`build.sh` 会自动完成编译 → 生成图标 → 打包 `.app` → 启动 app 全流程。无测试套件，验证方式是直接运行 app。

## 架构总览

这是一个 macOS 菜单栏应用（`LSUIElement=true`，无 Dock 图标），用 Swift Package Manager（`Package.swift`）管理，但实际构建走的是 `build.sh` 脚本直接调用 `swiftc`，而非 `swift build`。最低支持 macOS 12，编译目标 arm64-apple-macos13.0。

### 核心数据流

```
用户触发快捷键
    │
    ├─ 划词翻译: HotkeyManager(id=1) → TextGrabber.grab()
    │       ├─ 优先: AX API 直读选中文字（不污染剪贴板）
    │       └─ 降级: 模拟 Cmd+C，读取后恢复原剪贴板
    │
    ├─ 截图翻译: HotkeyManager(id=2) → ScreenshotOverlayWindow
    │       └─ 截图完成 → OCRManager.recognizeText(Vision 框架)
    │
    └─ 剪贴板历史: HotkeyManager(id=3) → ClipboardHistoryView
```

翻译请求统一走 `TranslationService` 协议，当前实现：
- `BaiduTranslationService`：使用 MD5 签名（`Insecure.MD5`），通过 `CryptoKit`
- `YoudaoTranslationService`：有道翻译 API

翻译结果在 `TranslationPanel`（浮动 NSPanel）中展示，面板跟随鼠标位置弹出，点击面板外自动关闭。

### 关键单例

- `SettingsManager.shared`：所有设置的 source of truth，用 `UserDefaults` 持久化，`@Published` 属性驱动实时更新
- `ClipboardHistoryManager.shared`：每秒轮询 `NSPasteboard.changeCount` 监听剪贴板变化

### 快捷键系统

`HotkeyManager` 用 Carbon `RegisterEventHotKey` 注册全局热键，签名 `"QKTR"`，用全局 `userData` 指针区分多个实例。设置变更时通过 Combine `Publishers.CombineLatest` 自动触发 `reregister()`。

### 权限依赖

- **辅助功能（Accessibility）**：划词翻译直读选中文字需要（`AXIsProcessTrusted()`），降级方案不需要
- **屏幕录制**：截图翻译需要（`CGPreflightScreenCaptureAccess()`）

### 目录结构

```
QuickTranslate/
├── App/          # 入口：QuickTranslateApp + AppDelegate（菜单栏、3个快捷键协调）
├── Core/         # HotkeyManager, OCRManager, TextGrabber, SpeechManager
├── Translation/  # TranslationService 协议 + Baidu/Youdao 实现
├── UI/           # TranslationPanel, TranslationView, ScreenshotOverlayWindow
├── Settings/     # SettingsManager, SettingsView
├── Clipboard/    # ClipboardHistoryManager, ClipboardHistoryView
└── Resources/    # Info.plist
```

### 添加新翻译引擎

1. 实现 `TranslationService` 协议
2. 在 `TranslationEngine` enum 添加 case
3. 在 `SettingsView` 添加对应 API Key 输入字段
