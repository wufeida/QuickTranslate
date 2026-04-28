import SwiftUI

@MainActor
class TranslationViewModel: ObservableObject {
    @Published var translatedText: String = ""
    @Published var detectedLanguage: String = ""
    @Published var phonetic: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""

    let originalText: String

    init(originalText: String) {
        self.originalText = originalText
    }

    func performTranslation() {
        isLoading = true
        errorMessage = ""
        let service = SettingsManager.shared.makeTranslationService()
        let target = SettingsManager.shared.targetLanguage

        Task {
            do {
                let result = try await service.translate(text: originalText, from: "auto", to: target)
                translatedText = result.translatedText
                detectedLanguage = result.detectedLanguage
                phonetic = result.phonetic ?? ""
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func speakOriginal() {
        let lang = detectedLanguage.hasPrefix("zh") ? "zh-CN" : detectedLanguage
        SpeechManager.shared.speak(originalText, language: lang)
    }

    func speakTranslation() {
        let lang = SettingsManager.shared.targetLanguage.hasPrefix("zh") ? "zh-CN" : SettingsManager.shared.targetLanguage
        SpeechManager.shared.speak(translatedText, language: lang)
    }

    func copyTranslation() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(translatedText, forType: .string)
    }
}

private struct PanelHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct TranslationView: View {
    @ObservedObject var viewModel: TranslationViewModel
    let onClose: () -> Void
    var onHeightChange: ((CGFloat) -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 原文区
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("原文")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(viewModel.originalText)
                            .font(.body)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)

                Divider()

                // 译文区
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("译文（\(SettingsManager.shared.selectedEngine.displayName)）")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if !viewModel.detectedLanguage.isEmpty {
                            Text(viewModel.detectedLanguage)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    if viewModel.isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("翻译中...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if !viewModel.errorMessage.isEmpty {
                        Text(viewModel.errorMessage)
                            .font(.body)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            let paragraphs = viewModel.translatedText
                                .components(separatedBy: "\n")
                                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                            VStack(alignment: .leading, spacing: paragraphs.count > 1 ? 10 : 4) {
                                ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                                    Text(paragraph)
                                        .font(.body)
                                        .textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            if !viewModel.phonetic.isEmpty {
                                Text(viewModel.phonetic)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Spacer()
                        Button(action: viewModel.speakOriginal) {
                            Label("朗读原文", systemImage: "speaker.wave.2")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isLoading)

                        Button(action: viewModel.copyTranslation) {
                            Label("复制", systemImage: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.translatedText.isEmpty)
                    }
                }
                .padding(12)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .frame(width: 320)
        .frame(maxHeight: 480)
        .background(GeometryReader { geo in
            Color.clear.preference(key: PanelHeightKey.self, value: geo.size.height)
        })
        .onPreferenceChange(PanelHeightKey.self) { height in
            guard height > 0 else { return }
            onHeightChange?(height)
        }
    }
}

struct ErrorToastView: View {
    let message: String
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.callout)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .frame(width: 260)
    }
}
