import AVFoundation

class SpeechManager: NSObject {
    static let shared = SpeechManager()
    private let synthesizer = AVSpeechSynthesizer()

    private override init() {
        super.init()
    }

    func speak(_ text: String, language: String = "zh-CN") {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
