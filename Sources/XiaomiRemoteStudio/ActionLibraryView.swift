import SwiftUI

struct ActionLibraryView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    private var normalizedQuery: String {
        store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredActions: [RemoteAction] {
        RemoteAction.catalog.filter { action in
            let matchesCategory = store.selectedCategory == nil || action.category == store.selectedCategory
            return matchesCategory && (
                normalizedQuery.isEmpty
                    || action.title.localizedCaseInsensitiveContains(normalizedQuery)
                    || action.subtitle.localizedCaseInsensitiveContains(normalizedQuery)
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.selectedSlot?.name ?? "按键动作")
                            .font(AppTypography.sectionTitle)
                        Text(currentAction.map { "当前：\($0.title)" } ?? "选择要执行的动作")
                            .font(AppTypography.supporting)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if currentAction != nil {
                        Button {
                            store.testSelectedAction()
                        } label: {
                            Label {
                                Text("测试")
                            } icon: {
                                AppIcon(symbol: "play.fill", size: AppIconSize.indicator)
                            }
                        }
                        .buttonStyle(InlineActionButtonStyle())
                        .help("立即测试当前按键动作")
                    }
                }

                if store.selectedSlot != nil {
                    SearchField(text: $store.searchText)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 18) {
                            CategoryTab(title: "全部", selected: store.selectedCategory == nil) {
                                store.selectedCategory = nil
                            }

                            ForEach(ActionCategory.allCases) { category in
                                CategoryTab(title: category.title, selected: store.selectedCategory == category) {
                                    store.selectedCategory = category
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 13)

            separator

            ScrollView {
                LazyVStack(spacing: 0) {
                    if store.selectedSlot == nil {
                        EmptySlotSelectionView()
                            .padding(.top, 72)
                    } else if filteredActions.isEmpty {
                        EmptyActionsView(query: normalizedQuery) {
                            store.searchText = ""
                            store.selectedCategory = nil
                        }
                        .padding(.top, 50)
                    } else {
                        ForEach(Array(filteredActions.enumerated()), id: \.element.id) { index, action in
                            ActionRow(action: action, isAssigned: currentAction?.id == action.id)

                            if index < filteredActions.count - 1 {
                                separator
                                    .padding(.leading, 48)
                            }
                        }
                    }
                }
            }

            separator

            Text(store.selectedSlot == nil ? "先选择遥控器按键" : "选择后自动保存到本机")
                .font(AppTypography.supportingMedium)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 20)
                .frame(height: 44, alignment: .leading)
        }
        .background(AppTheme.surface(for: colorScheme))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(AppTheme.separator(for: colorScheme))
                .frame(width: 1)
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(AppTheme.separator(for: colorScheme))
            .frame(height: 1)
    }

    private var currentAction: RemoteAction? {
        guard let slot = store.selectedSlot else { return nil }
        return store.action(for: slot.id)
    }
}

private struct SearchField: View {
    @Binding var text: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            AppIcon(symbol: "magnifyingglass", size: AppIconSize.control)
                .foregroundStyle(.secondary)

            TextField("搜索动作", text: $text)
                .textFieldStyle(.plain)
                .font(AppTypography.body)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    AppIcon(symbol: "xmark.circle.fill", size: AppIconSize.control)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: AppMetrics.controlHeight)
        .background(AppTheme.elevatedSurface(for: colorScheme).opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.radiusControl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppMetrics.radiusControl, style: .continuous)
                .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
        }
    }
}

private struct CategoryTab: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(selected ? AppTypography.label : AppTypography.supporting)
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .padding(.bottom, 7)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(selected ? AppTheme.accent(for: colorScheme) : .clear)
                        .frame(height: 1.5)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(QuietButtonStyle())
    }
}

private struct ActionRow: View {
    let action: RemoteAction
    let isAssigned: Bool

    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Button {
            store.assignToSelectedSlot(action)
        } label: {
            HStack(spacing: 12) {
                AppIcon(symbol: action.symbol, size: AppIconSize.row)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(action.title)
                        .font(AppTypography.bodyMedium)
                    Text(action.subtitle)
                        .font(AppTypography.supporting)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                if isAssigned {
                    AppIcon(symbol: "checkmark", size: AppIconSize.indicator)
                        .foregroundStyle(AppTheme.accent(for: colorScheme))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: AppMetrics.rowHeight)
            .background(
                isAssigned
                    ? AppTheme.accent(for: colorScheme).opacity(0.065)
                    : (isHovered ? Color.primary.opacity(0.025) : .clear)
            )
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(isAssigned ? AppTheme.accent(for: colorScheme) : .clear)
                    .frame(width: 3, height: 34)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(QuietButtonStyle())
        .onDrag {
            store.beginDragging(action)
            return NSItemProvider(object: action.id as NSString)
        }
        .onHover { isHovered = $0 }
    }
}

private struct EmptySlotSelectionView: View {
    var body: some View {
        ContentUnavailableView {
            Label {
                Text("先选择一个按键")
            } icon: {
                AppIcon(symbol: "button.programmable", size: 38)
            }
        } description: {
            Text("在遥控器图上选择按键后，再为它分配动作。")
        }
        .frame(maxWidth: .infinity)
    }
}

private struct EmptyActionsView: View {
    let query: String
    let reset: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label {
                Text("没有匹配的动作")
            } icon: {
                AppIcon(symbol: "magnifyingglass", size: 38)
            }
        } description: {
            if query.isEmpty {
                Text("当前分类暂时没有可用动作。")
            } else {
                Text("没有找到“\(query)”相关动作，换个关键词试试。")
                    .lineLimit(2)
            }
        } actions: {
            Button("清除筛选", action: reset)
                .buttonStyle(SecondaryActionButtonStyle())
        }
        .frame(maxWidth: .infinity)
    }
}
