import Foundation

struct TranslationResult {
    let originalText: String
    let translatedText: String
    let detectedLanguage: String
    let phonetic: String?
}

protocol TranslationService {
    var name: String { get }
    func translate(text: String, from: String, to: String) async throws -> TranslationResult
}

enum TranslationError: LocalizedError {
    case invalidAPIKey
    case networkError(Error)
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey: return "API Key 无效，请在偏好设置中配置"
        case .networkError(let err): return "网络错误：\(err.localizedDescription)"
        case .invalidResponse: return "返回数据格式异常"
        case .apiError(let msg): return "API 错误：\(msg)"
        }
    }
}

enum TranslationEngine: String, CaseIterable {
    case baidu = "baidu"
    case youdao = "youdao"

    var displayName: String {
        switch self {
        case .baidu: return "百度翻译"
        case .youdao: return "有道翻译"
        }
    }

    func makeService() -> TranslationService {
        switch self {
        case .baidu: return BaiduTranslationService()
        case .youdao: return YoudaoTranslationService()
        }
    }
}
