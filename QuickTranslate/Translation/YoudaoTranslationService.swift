import Foundation
import CryptoKit

class YoudaoTranslationService: TranslationService {
    let name = "有道翻译"

    func translate(text: String, from: String = "auto", to: String = "zh-CHS") async throws -> TranslationResult {
        let appKey = SettingsManager.shared.youdaoAppKey
        let appSecret = SettingsManager.shared.youdaoAppSecret
        guard !appKey.isEmpty, !appSecret.isEmpty else {
            throw TranslationError.invalidAPIKey
        }

        let salt = UUID().uuidString
        let curtime = String(Int(Date().timeIntervalSince1970))
        let input = truncateInput(text)
        let signStr = appKey + input + salt + curtime + appSecret
        let sign = sha256(signStr)

        var components = URLComponents()
        components.queryItems = [
            .init(name: "q", value: text),
            .init(name: "from", value: from),
            .init(name: "to", value: to),
            .init(name: "appKey", value: appKey),
            .init(name: "salt", value: salt),
            .init(name: "sign", value: sign),
            .init(name: "signType", value: "v3"),
            .init(name: "curtime", value: curtime),
        ]

        var request = URLRequest(url: URL(string: "https://openapi.youdao.com/api")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = components.query?.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(YoudaoResponse.self, from: data)

        if decoded.errorCode != "0" {
            throw TranslationError.apiError("错误码 \(decoded.errorCode)")
        }
        guard let translations = decoded.translation, !translations.isEmpty else {
            throw TranslationError.invalidResponse
        }

        let phonetic = decoded.basic?.phonetic
        return TranslationResult(
            originalText: text,
            translatedText: translations.joined(separator: "\n"),
            detectedLanguage: decoded.l ?? from,
            phonetic: phonetic
        )
    }

    private func truncateInput(_ text: String) -> String {
        let count = text.count
        if count <= 20 { return text }
        let start = String(text.prefix(10))
        let end = String(text.suffix(10))
        return "\(start)\(count)\(end)"
    }

    private func sha256(_ string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

private struct YoudaoResponse: Decodable {
    let errorCode: String
    let translation: [String]?
    let basic: YoudaoBasic?
    let l: String?
}

private struct YoudaoBasic: Decodable {
    let phonetic: String?
    let explains: [String]?
}
