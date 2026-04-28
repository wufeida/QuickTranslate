import AppKit

class ClipboardHistoryManager: ObservableObject {
    static let shared = ClipboardHistoryManager()

    struct Item: Identifiable {
        let id = UUID()
        let text: String
        let date: Date
    }

    @Published private(set) var items: [Item] = []

    private var lastChangeCount: Int
    private var timer: Timer?

    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
        let t = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        guard let text = pb.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text != items.first?.text else { return }

        let limit = max(1, min(100, SettingsManager.shared.clipboardHistoryLimit))
        items.insert(Item(text: text, date: Date()), at: 0)
        if items.count > limit { items.removeLast() }
    }

    func copyItem(_ item: Item) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func deleteItem(_ item: Item) {
        items.removeAll { $0.id == item.id }
    }

    func clear() {
        items.removeAll()
    }
}
