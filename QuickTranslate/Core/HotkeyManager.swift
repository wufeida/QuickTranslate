import Carbon
import AppKit

class HotkeyManager {
    private let hotkeyID: UInt32
    private let keyCodeProvider: () -> Int
    private let modifiersProvider: () -> Int
    private let callback: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    init(id: UInt32,
         keyCode: @escaping () -> Int,
         modifiers: @escaping () -> Int,
         callback: @escaping () -> Void) {
        self.hotkeyID = id
        self.keyCodeProvider = keyCode
        self.modifiersProvider = modifiers
        self.callback = callback
    }

    func register() {
        let hotKeyID = EventHotKeyID(signature: fourCharCode("QKTR"), id: hotkeyID)
        let status = RegisterEventHotKey(
            UInt32(keyCodeProvider()),
            UInt32(modifiersProvider()),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr else { return }

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let userData, let event else { return OSStatus(eventNotHandledErr) }
            // 检查触发的快捷键 ID 是否与本实例匹配
            var firedID = EventHotKeyID()
            GetEventParameter(event,
                              EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID),
                              nil,
                              MemoryLayout<EventHotKeyID>.size,
                              nil,
                              &firedID)
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            guard firedID.id == manager.hotkeyID else { return OSStatus(eventNotHandledErr) }
            manager.callback()
            return noErr
        }, 1, &eventSpec, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
    }

    func reregister() {
        unregister()
        register()
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    deinit { unregister() }

    // MARK: - 键名显示

    static func displayString(keyCode: Int, modifiers: Int) -> String {
        var s = ""
        if modifiers & Int(controlKey) != 0 { s += "⌃" }
        if modifiers & Int(optionKey)  != 0 { s += "⌥" }
        if modifiers & Int(shiftKey)   != 0 { s += "⇧" }
        if modifiers & Int(cmdKey)     != 0 { s += "⌘" }
        s += keyName(for: keyCode)
        return s
    }

    static func nsModifiers(fromCarbon carbonMods: Int) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbonMods & Int(cmdKey)     != 0 { flags.insert(.command) }
        if carbonMods & Int(optionKey)  != 0 { flags.insert(.option) }
        if carbonMods & Int(shiftKey)   != 0 { flags.insert(.shift) }
        if carbonMods & Int(controlKey) != 0 { flags.insert(.control) }
        return flags
    }

    static func keyEquivalentChar(for keyCode: Int) -> String {
        let table: [Int: String] = [
            0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
            8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r",
            16: "y", 17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p", 37: "l",
            38: "j", 39: "'", 40: "k", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "n", 46: "m", 47: ".", 50: "`",
            36: "\r", 48: "\t", 49: " ", 51: "\u{8}", 53: "\u{1b}",
            123: "\u{F702}", 124: "\u{F703}", 125: "\u{F701}", 126: "\u{F700}",
        ]
        return table[keyCode] ?? ""
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> Int {
        var m = 0
        if flags.contains(.command) { m |= Int(cmdKey) }
        if flags.contains(.option)  { m |= Int(optionKey) }
        if flags.contains(.shift)   { m |= Int(shiftKey) }
        if flags.contains(.control) { m |= Int(controlKey) }
        return m
    }

    private static func keyName(for keyCode: Int) -> String {
        let table: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 50: "`",
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "Esc",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        ]
        return table[keyCode] ?? "(\(keyCode))"
    }
}

private func fourCharCode(_ string: String) -> FourCharCode {
    var result: FourCharCode = 0
    for char in string.utf8.prefix(4) {
        result = (result << 8) + FourCharCode(char)
    }
    return result
}
