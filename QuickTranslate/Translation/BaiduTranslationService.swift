import Foundation
import CryptoKit

class BaiduTranslationService: TranslationService {
    let name = "百度翻译"

    func translate(text: String, from: String = "auto", to: String = "zh") async throws -> TranslationResult {
        let appID = SettingsManager.shared.baiduAppID
        let secretKey = SettingsManager.shared.baiduSecretKey
        guard !appID.isEmpty, !secretKey.isEmpty else {
            throw TranslationError.invalidAPIKey
        }

        let salt = String(Int.random(in: 10000...99999))
        let sign = md5(appID + text + salt + secretKey)

        var components = URLComponents(string: "https://fanyi-api.baidu.com/api/trans/vip/translate")!
        components.queryItems = [
            .init(name: "q", value: text),
            .init(name: "from", value: from),
            .init(name: "to", value: to),
            .init(name: "appid", value: appID),
            .init(name: "salt", value: salt),
            .init(name: "sign", value: sign),
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let decoded = try JSONDecoder().decode(BaiduResponse.self, from: data)

        if let error = decoded.error_code {
            throw TranslationError.apiError("错误码 \(error)：\(decoded.error_msg ?? "")")
        }
        guard let result = decoded.trans_result?.first else {
            throw TranslationError.invalidResponse
        }

        return TranslationResult(
            originalText: text,
            translatedText: result.dst,
            detectedLanguage: decoded.from ?? from,
            phonetic: nil
        )
    }

    private func md5(_ string: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

private struct BaiduResponse: Decodable {
    let from: String?
    let to: String?
    let trans_result: [BaiduTransItem]?
    let error_code: String?
    let error_msg: String?
}

private struct BaiduTransItem: Decodable {
    let src: String
    let dst: String
}
