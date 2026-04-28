import SwiftUI

struct ClipboardHistoryView: View {
    @ObservedObject private var manager = ClipboardHistoryManager.shared
    @State private var copiedID: UUID?
    @State private var searchText = ""

    private var filtered: [ClipboardHistoryManager.Item] {
        guard !searchText.isEmpty else { return manager.items }
        return manager.items.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            Divider()
            content
        }
        .frame(minWidth: 300, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.accentColor)
                .font(.system(size: 14, weight: .medium))

            Text("剪贴板历史")
                .font(.system(size: 14, weight: .semibold))

            if !manager.items.isEmpty {
                Text("\(manager.items.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.accentColor.opacity(0.85))
                    .clipShape(Capsule())
            }

            Spacer()

            if !manager.items.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { manager.clear() }
                } label: {
                    Label("清空", systemImage: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.06))
                .cornerRadius(6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 12))
            TextField("搜索历史记录…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - 内容区

    @ViewBuilder
    private var content: some View {
        if manager.items.isEmpty {
            emptyState
        } else if filtered.isEmpty {
            noResultState
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered) { item in
                        HistoryRow(
                            item: item,
                            isCopied: copiedID == item.id,
                            onCopy: {
                                manager.copyItem(item)
                                copiedID = item.id
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    if copiedID == item.id { copiedID = nil }
                                }
                            },
                            onDelete: {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    manager.deleteItem(item)
                                }
                            }
                        )
                        if item.id != filtered.last?.id {
                            Divider()
                                .padding(.leading, 16)
                                .opacity(0.5)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - 空态

    private var emptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 64, height: 64)
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 28))
                    .foregroundColor(.accentColor.opacity(0.6))
            }
            Text("暂无历史记录")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            Text("复制任意文字后将自动记录")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundColor(.secondary.opacity(0.5))
            Text("无匹配结果")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 历史记录行

private struct HistoryRow: View {
    let item: ClipboardHistoryManager.Item
    let isCopied: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // 左侧类型图标
            Image(systemName: "doc.text")
                .font(.system(size: 13))
                .foregroundColor(.accentColor.opacity(0.7))
                .frame(width: 20)

            // 内容
            VStack(alignment: .leading, spacing: 3) {
                Text(item.text)
                    .lineLimit(2)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(item.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)

            // 操作按钮（hover 时显示）
            if isHovered || isCopied {
                HStack(spacing: 6) {
                    Button {
                        onCopy()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 10, weight: .medium))
                            Text(isCopied ? "已复制" : "复制")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(isCopied ? .green : .white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isCopied ? Color.green.opacity(0.15) : Color.accentColor)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(isCopied)

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(5)
                            .background(Color.primary.opacity(0.07))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .trailing)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
                .padding(.horizontal, 6)
        )
        .contentShape(Rectangle())
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = h }
        }
        .onTapGesture { onCopy() }
    }
}
