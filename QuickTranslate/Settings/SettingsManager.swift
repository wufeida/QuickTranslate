import Foundation
import Carbon

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    @Published var selectedEngine: TranslationEngine {
        didSet { defaults.set(selectedEngine.rawValue, forKey: "selectedEngine") }
    }
    @Published var targetLanguage: String {
        didSet { defaults.set(targetLanguage, forKey: "targetLanguage") }
    }
    @Published var baiduAppID: String {
        didSet { defaults.set(baiduAppID, forKey: "baiduAppID") }
    }
    @Published var baiduSecretKey: String {
        didSet { defaults.set(baiduSecretKey, forKey: "baiduSecretKey") }
    }
    @Published var youdaoAppKey: String {
        didSet { defaults.set(youdaoAppKey, forKey: "youdaoAppKey") }
    }
    @Published var youdaoAppSecret: String {
        didSet { defaults.set(youdaoAppSecret, forKey: "youdaoAppSecret") }
    }

    // 划词翻译快捷键：默认 Option+D
    @Published var hotkeyCode: Int {
        didSet { defaults.set(hotkeyCode, forKey: "hotkeyCode") }
    }
    @Published var hotkeyModifiers: Int {
        didSet { defaults.set(hotkeyModifiers, forKey: "hotkeyModifiers") }
    }

    // 截图翻译快捷键：默认 Option+A
    @Published var ocrHotkeyCode: Int {
        didSet { defaults.set(ocrHotkeyCode, forKey: "ocrHotkeyCode") }
    }
    @Published var ocrHotkeyModifiers: Int {
        didSet { defaults.set(ocrHotkeyModifiers, forKey: "ocrHotkeyModifiers") }
    }

    // 剪贴板历史最大条数：默认 20
    @Published var clipboardHistoryLimit: Int {
        didSet { defaults.set(clipboardHistoryLimit, forKey: "clipboardHistoryLimit") }
    }

    // 剪贴板历史快捷键：默认 Option+V
    @Published var clipboardHotkeyCode: Int {
        didSet { defaults.set(clipboardHotkeyCode, forKey: "clipboardHotkeyCode") }
    }
    @Published var clipboardHotkeyModifiers: Int {
        didSet { defaults.set(clipboardHotkeyModifiers, forKey: "clipboardHotkeyModifiers") }
    }

    // 输入翻译快捷键：默认 Option+T
    @Published var inputHotkeyCode: Int {
        didSet { defaults.set(inputHotkeyCode, forKey: "inputHotkeyCode") }
    }
    @Published var inputHotkeyModifiers: Int {
        didSet { defaults.set(inputHotkeyModifiers, forKey: "inputHotkeyModifiers") }
    }

    private init() {
        selectedEngine = TranslationEngine(rawValue: defaults.string(forKey: "selectedEngine") ?? "") ?? .baidu
        targetLanguage = defaults.string(forKey: "targetLanguage") ?? "zh"
        baiduAppID = defaults.string(forKey: "baiduAppID") ?? ""
        baiduSecretKey = defaults.string(forKey: "baiduSecretKey") ?? ""
        youdaoAppKey = defaults.string(forKey: "youdaoAppKey") ?? ""
        youdaoAppSecret = defaults.string(forKey: "youdaoAppSecret") ?? ""
        let savedCode = defaults.integer(forKey: "hotkeyCode")
        hotkeyCode = savedCode == 0 ? 2 : savedCode
        let savedMods = defaults.integer(forKey: "hotkeyModifiers")
        hotkeyModifiers = savedMods == 0 ? Int(optionKey) : savedMods
        let savedOcrCode = defaults.integer(forKey: "ocrHotkeyCode")
        ocrHotkeyCode = savedOcrCode == 0 ? 0 : savedOcrCode   // 0 = A
        let savedOcrMods = defaults.integer(forKey: "ocrHotkeyModifiers")
        ocrHotkeyModifiers = savedOcrMods == 0 ? Int(optionKey) : savedOcrMods
        let savedLimit = defaults.integer(forKey: "clipboardHistoryLimit")
        clipboardHistoryLimit = savedLimit == 0 ? 20 : savedLimit
        let savedClipCode = defaults.integer(forKey: "clipboardHotkeyCode")
        clipboardHotkeyCode = savedClipCode == 0 ? 9 : savedClipCode  // 9 = V
        let savedClipMods = defaults.integer(forKey: "clipboardHotkeyModifiers")
        clipboardHotkeyModifiers = savedClipMods == 0 ? Int(optionKey) : savedClipMods
        let savedInputCode = defaults.integer(forKey: "inputHotkeyCode")
        inputHotkeyCode = savedInputCode == 0 ? 17 : savedInputCode  // 17 = T
        let savedInputMods = defaults.integer(forKey: "inputHotkeyModifiers")
        inputHotkeyModifiers = savedInputMods == 0 ? Int(optionKey) : savedInputMods
    }

    func makeTranslationService() -> TranslationService {
        selectedEngine.makeService()
    }
}
