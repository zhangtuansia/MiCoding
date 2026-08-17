import SwiftUI
import UniformTypeIdentifiers

enum ActionLibraryLayoutMetrics {
    // Freshly measured from Options+ at 1,180 × 760: the fixed drawer
    // header spans y=0...70 before the 26 pt search inset.
    static let headerHeight: CGFloat = 70
    static let headerLeadingPadding: CGFloat = 30
    static let headerTitleOpticalScale: CGFloat = 1.055
    static let headerTitleOpticalYOffset: CGFloat = -2
    static let searchTextOpticalXOffset: CGFloat = 1
    static let searchTextOpticalYOffset: CGFloat = -1.5
    static let searchPlaceholderOpacity: CGFloat = 0.45
    static let searchIconSize: CGFloat = 18.5
    static let searchIconXOffset: CGFloat = 1.5
    static let searchIconYOffset: CGFloat = 0.5
    static let recommendedTitleOpticalXOffset: CGFloat = 1.5
    static let recommendedTitleOpticalYOffset: CGFloat = -1
    static let collapsibleTitleOpticalXOffset: CGFloat = 1
    static let smartActionsTitleOpticalYOffset: CGFloat = 3.5
    static let otherActionsTitleOpticalYOffset: CGFloat = 0
    static let categoryTrailingPadding: CGFloat = 27.5
    static let categoryChevronSize: CGFloat = 18
    static let categoryChevronYOffset: CGFloat = 1
    static let compactRowTextOpticalXOffset: CGFloat = 0.5
    static let compactRowTextOpticalYOffset: CGFloat = 2
    static let compactLatinRowTextOpticalXScale: CGFloat = 1.03
    static let compactSelectedRowTextOpticalXOffset: CGFloat = 0.5
    static let compactSelectedRowTextOpticalYOffset: CGFloat = -0.5
    static let searchTextOpticalXScale: CGFloat = 0.99
    static let recommendedTitleOpticalXScale: CGFloat = 1
    static let smartActionsTitleOpticalXScale: CGFloat = 0.96
    static let smartActionsTitleOpticalYScale: CGFloat = 0.955
    static let actionsRingDetailHorizontalPadding: CGFloat = 13
    static let actionsRingConfigurationTopPadding: CGFloat = 26
    static let actionsRingDescriptionXOffset: CGFloat = -3.5
    static let actionsRingDescriptionYOffset: CGFloat = 2.5
    static let actionsRingConfigurationXOffset: CGFloat = -3.5
    static let shortcutRecorderTopPadding: CGFloat = 20
    static let shortcutRecorderDetailHeight: CGFloat = 188
    static let shortcutRecorderRowHeight: CGFloat = 236
    static let applicationPickerDetailHeight: CGFloat = 140
    static let applicationPickerRowHeight: CGFloat = 188
}

private let chooseApplicationAction = RemoteAction(
    id: "choose-application",
    title: "打开应用程序",
    subtitle: "选择任意已安装的 macOS App",
    symbol: "app.dashed",
    category: .apps,
    tint: .blue
)

struct ActionLibraryView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var expandedCategory: ActionCategory? = .recommended

    private var normalizedQuery: String {
        store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var currentAction: RemoteAction? {
        guard let slot = store.selectedSlot else { return nil }
        return store.action(for: slot.id, trigger: store.selectedTrigger)
    }

    private var searchResults: [RemoteAction] {
        guard !normalizedQuery.isEmpty else { return [] }
        return availableActions.filter {
            $0.title.localizedCaseInsensitiveContains(normalizedQuery)
                || $0.devicePresentationTitle.localizedCaseInsensitiveContains(normalizedQuery)
                || $0.subtitle.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    private var installedSmartActions: [RemoteAction] {
        store.installedSmartActionCatalog.filter(isAvailableForSelectedButton)
    }

    private var availableActions: [RemoteAction] {
        (RemoteAction.catalog.filter { $0.category != .shortcut }
            + [chooseApplicationAction])
            .filter(isAvailableForSelectedButton)
            + installedSmartActions
    }

    private func isAvailableForSelectedButton(_ action: RemoteAction) -> Bool {
        guard let slot = store.selectedSlot else { return false }
        return slot.accepts(action, trigger: store.selectedTrigger)
    }

    private var recommendedActions: [RemoteAction] {
        let recommendedIDs = [
            "browser-back",
            "copy",
            "volume-down",
            "undo",
            "keyboard-shortcut",
            "spotlight",
            "show-actions-ring"
        ]
        var actions = recommendedIDs.compactMap { id in
            RemoteAction.catalog.first(where: { $0.id == id })
        }.filter(isAvailableForSelectedButton)
        if isAvailableForSelectedButton(chooseApplicationAction) {
            if let shortcutIndex = actions.firstIndex(where: { $0.id == "keyboard-shortcut" }) {
                actions.insert(chooseApplicationAction, at: shortcutIndex)
            } else {
                actions.append(chooseApplicationAction)
            }
        }
        if let currentAction {
            if currentAction.id.hasPrefix("recorded-keyboard-shortcut-"),
               let shortcutIndex = actions.firstIndex(where: { $0.id == "keyboard-shortcut" }) {
                actions[shortcutIndex] = currentAction
                return actions
            }
            let alreadyRecommended = actions.contains(where: { $0.id == currentAction.id })
            if !alreadyRecommended, isAvailableForSelectedButton(currentAction) {
                actions.insert(currentAction, at: 0)
            }
        }
        return actions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            actionHeader
            actionControls
            separator

            ScrollView {
                LazyVStack(spacing: 0) {
                    if normalizedQuery.isEmpty {
                        categoryGroup(.recommended, title: "推荐", actions: recommendedActions)
                        categoryGroup(.shortcut, title: "SMART ACTIONS", actions: installedSmartActions)
                        categoryGroup(
                            .system,
                            title: "其他动作",
                            actions: (RemoteAction.catalog.filter {
                                [.system, .media, .apps].contains($0.category)
                            } + [chooseApplicationAction])
                                .filter(isAvailableForSelectedButton)
                        )
                    } else if searchResults.isEmpty {
                        ActionLibraryEmptySearchView(query: normalizedQuery) {
                            store.searchText = ""
                        }
                    } else {
                        Text("结果")
                            .font(.custom("AvenirNext-DemiBold", size: 14))
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                            .padding(.horizontal, 34)

                        ForEach(searchResults) { action in
                            CompactActionRow(action: action, selected: action.id == currentAction?.id)
                        }
                    }
                }
            }

        }
        .background(AppTheme.surface(for: colorScheme))
        .onChange(of: store.selectedSlotID) { _, _ in
            expandedCategory = .recommended
        }
        .onAppear { expandedCategory = .recommended }
    }

    private var actionHeader: some View {
        HStack(spacing: 0) {
            triggerMenu
            Spacer()
        }
        .padding(.leading, ActionLibraryLayoutMetrics.headerLeadingPadding)
        .padding(.trailing, 20)
        .frame(height: ActionLibraryLayoutMetrics.headerHeight)
        .background(AppTheme.elevatedSurface(for: colorScheme))
    }

    private var triggerMenu: some View {
        Menu {
            ForEach(RemoteTrigger.allCases) { trigger in
                Button {
                    store.selectedTrigger = trigger
                } label: {
                    if store.selectedTrigger == trigger {
                        Label(trigger.title, systemImage: "checkmark")
                    } else {
                        Text(trigger.title)
                    }
                }
            }

            if currentAction != nil {
                Divider()

                Button("测试当前动作") {
                    store.testSelectedAction()
                }

                Button("清除当前分配", role: .destructive) {
                    store.clearSelectedAssignment()
                }
            }
        } label: {
            Text("动作")
                // The reference uses a medium Chinese face here; requesting
                // Avenir Next DemiBold makes PingFang's fallback noticeably
                // heavier even though the glyph bounds are already correct.
                .font(.system(size: 21, weight: .regular))
                .foregroundStyle(AppTheme.text(for: colorScheme))
                .scaleEffect(
                    x: ActionLibraryLayoutMetrics.headerTitleOpticalScale,
                    y: ActionLibraryLayoutMetrics.headerTitleOpticalScale
                )
                .frame(height: 32)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .offset(y: ActionLibraryLayoutMetrics.headerTitleOpticalYOffset)
        .help("动作 · \(store.selectedTrigger.title)；点按可切换触发方式、测试或清除")
        .accessibilityLabel("触发方式")
        .accessibilityValue(store.selectedTrigger.title)
    }

    private var actionControls: some View {
        SearchField(text: $store.searchText)
            .padding(.top, 28)
            .padding(.bottom, 4)
    }

    private func actions(in category: ActionCategory) -> [RemoteAction] {
        RemoteAction.catalog.filter {
            $0.category == category && isAvailableForSelectedButton($0)
        }
    }

    private func categoryGroup(
        _ category: ActionCategory,
        title: String,
        actions: [RemoteAction]
    ) -> some View {
        ActionCategoryGroup(
            category: category,
            title: title,
            actions: actions,
            expanded: category == .recommended || expandedCategory == category,
            collapsible: category != .recommended,
            currentActionID: currentAction?.id
        ) {
            withAnimation(.easeOut(duration: 0.16)) {
                expandedCategory = expandedCategory == category ? nil : category
            }
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(AppTheme.separator(for: colorScheme))
            .frame(height: 1)
    }
}

private struct SearchField: View {
    @Binding var text: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 9) {
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text("搜索")
                        .foregroundStyle(Color.secondary.opacity(ActionLibraryLayoutMetrics.searchPlaceholderOpacity))
                        .offset(y: ActionLibraryLayoutMetrics.searchTextOpticalYOffset)
                        .scaleEffect(
                            x: ActionLibraryLayoutMetrics.searchTextOpticalXScale,
                            y: 1,
                            anchor: .leading
                        )
                        .offset(x: ActionLibraryLayoutMetrics.searchTextOpticalXOffset)
                        .allowsHitTesting(false)
                }

                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .offset(y: ActionLibraryLayoutMetrics.searchTextOpticalYOffset)
            }
            .font(.custom("AvenirNext-Medium", size: 16))

            if text.isEmpty {
                AppIcon(
                    symbol: "magnifyingglass",
                    size: ActionLibraryLayoutMetrics.searchIconSize
                )
                    .foregroundStyle(AppTheme.text(for: colorScheme))
                    .offset(
                        x: ActionLibraryLayoutMetrics.searchIconXOffset,
                        y: ActionLibraryLayoutMetrics.searchIconYOffset
                    )
            } else {
                Button {
                    text = ""
                } label: {
                    Circle()
                        .fill(AppTheme.accent(for: colorScheme))
                        .frame(width: 18, height: 18)
                        .overlay {
                            AppIcon(symbol: "xmark", size: 10)
                                .foregroundStyle(AppTheme.onAccent(for: colorScheme))
                        }
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(.leading, 32)
        .padding(.trailing, 29)
        .frame(height: 48)
        .background(AppTheme.surface(for: colorScheme))
    }
}

private struct ActionLibraryEmptySearchView: View {
    let query: String
    let clear: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            AppIcon(symbol: "search-x", size: 24)
                .foregroundStyle(Color.secondary)
                .frame(width: 44, height: 44)
                .background(AppTheme.elevatedSurface(for: colorScheme).opacity(0.58))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            Text("没有找到动作")
                .font(AppTypography.title)
                .foregroundStyle(AppTheme.text(for: colorScheme))
                .padding(.top, 16)

            Text("“\(query)”没有匹配项")
                .font(AppTypography.supporting)
                .foregroundStyle(Color.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.top, 5)

            Button("清除搜索", action: clear)
                .buttonStyle(SecondaryActionButtonStyle(width: 112))
                .padding(.top, 18)
        }
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .center)
        .accessibilityElement(children: .contain)
    }
}

private struct ActionCategoryGroup: View {
    let category: ActionCategory
    let title: String
    let actions: [RemoteAction]
    let expanded: Bool
    let collapsible: Bool
    let currentActionID: String?
    let toggle: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            if collapsible {
                Button(action: toggle) {
                    categoryHeader
                }
                .buttonStyle(QuietButtonStyle())
            } else {
                categoryHeader
            }

            if expanded {
                ForEach(actions) { action in
                    CompactActionRow(action: action, selected: action.id == currentActionID)
                }
            }

            Rectangle()
                .fill(Color.primary.opacity(0.065))
                .frame(height: 1)
        }
    }

    private var categoryHeader: some View {
        HStack {
            Text(title)
                .font(
                    .custom(
                        title == "SMART ACTIONS" ? "AvenirNext-Medium" : "AvenirNext-DemiBold",
                        size: 14
                    )
                )
                .foregroundStyle(colorScheme == .dark ? AppTheme.text(for: colorScheme) : .black)
                .scaleEffect(
                    x: !collapsible
                        ? ActionLibraryLayoutMetrics.recommendedTitleOpticalXScale
                        : (title == "SMART ACTIONS"
                            ? ActionLibraryLayoutMetrics.smartActionsTitleOpticalXScale
                            : 1),
                    y: title == "SMART ACTIONS"
                        ? ActionLibraryLayoutMetrics.smartActionsTitleOpticalYScale
                        : 1,
                    anchor: .leading
                )
                .offset(
                    x: !collapsible
                        ? ActionLibraryLayoutMetrics.recommendedTitleOpticalXOffset
                        : ActionLibraryLayoutMetrics.collapsibleTitleOpticalXOffset,
                    y: !collapsible
                        ? ActionLibraryLayoutMetrics.recommendedTitleOpticalYOffset
                        : (title == "SMART ACTIONS"
                            ? ActionLibraryLayoutMetrics.smartActionsTitleOpticalYOffset
                            : ActionLibraryLayoutMetrics.otherActionsTitleOpticalYOffset)
                )
            Spacer()
            if collapsible {
                AppIcon(
                    symbol: expanded ? "chevron.up" : "chevron.down",
                    size: ActionLibraryLayoutMetrics.categoryChevronSize
                )
                .foregroundStyle(colorScheme == .dark ? AppTheme.text(for: colorScheme) : .black)
                .offset(y: ActionLibraryLayoutMetrics.categoryChevronYOffset)
            }
        }
        .padding(.leading, 34)
        .padding(.trailing, collapsible ? ActionLibraryLayoutMetrics.categoryTrailingPadding : 34)
        .frame(height: collapsible ? 48 : 56)
        .contentShape(Rectangle())
    }
}

private struct CompactActionRow: View {
    let action: RemoteAction
    let selected: Bool

    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var hovered = false
    @State private var showsShortcutRecorder = false
    @State private var showsApplicationPicker = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                if isKeyboardShortcut {
                    showsShortcutRecorder.toggle()
                    showsApplicationPicker = false
                } else if isApplicationPicker {
                    showsApplicationPicker.toggle()
                    showsShortcutRecorder = false
                } else {
                    store.assignToSelectedSlot(action)
                }
            } label: {
                HStack(spacing: 15) {
                    Circle()
                        .fill(rowSelected ? AppTheme.onAccent(for: colorScheme) : Color.primary.opacity(0.11))
                        .frame(width: 18, height: 18)
                        .overlay {
                            if rowSelected {
                                Circle()
                                    .fill(AppTheme.accent(for: colorScheme))
                                    .frame(width: 6, height: 6)
                            }
                        }

                    Text(action.devicePresentationTitle)
                        .font(
                            .custom(
                                rowSelected ? "AvenirNext-DemiBold" : "AvenirNext-Regular",
                                size: 14
                            )
                        )
                        .foregroundStyle(
                            rowSelected
                                ? AppTheme.onAccent(for: colorScheme)
                                : (colorScheme == .dark ? AppTheme.text(for: colorScheme) : .black)
                        )
                        .scaleEffect(
                            x: usesLatinOpticalScale
                                ? ActionLibraryLayoutMetrics.compactLatinRowTextOpticalXScale
                                : 1,
                            y: 1,
                            anchor: .leading
                        )
                        .offset(
                            x: rowSelected
                                ? ActionLibraryLayoutMetrics.compactSelectedRowTextOpticalXOffset
                                : ActionLibraryLayoutMetrics.compactRowTextOpticalXOffset,
                            y: rowSelected
                                ? ActionLibraryLayoutMetrics.compactSelectedRowTextOpticalYOffset
                                : ActionLibraryLayoutMetrics.compactRowTextOpticalYOffset
                        )
                        .lineLimit(1)

                    Spacer()

                    if action.id == "show-actions-ring" {
                        Text("新")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(red: 45 / 255, green: 145 / 255, blue: 70 / 255))
                            .frame(width: 20, height: 20)
                            .background(Color(red: 231 / 255, green: 249 / 255, blue: 232 / 255))
                            .clipShape(Circle())
                            .padding(.trailing, 1)
                    }
                }
                .padding(.horizontal, 15)
                .frame(height: rowSelected ? 48 : 32)
                .background(
                    rowSelected
                        ? AppTheme.accent(for: colorScheme)
                        : (hovered ? Color.primary.opacity(0.025) : Color.clear)
                )
                .clipShape(RoundedRectangle(cornerRadius: rowSelected ? 4 : 0, style: .continuous))
                .padding(.leading, 17)
                .padding(.trailing, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(QuietButtonStyle())

            if selected && action.id == "show-actions-ring" {
                actionsRingDetail
                    .offset(y: -2)
            } else if showsInlineShortcutRecorder {
                shortcutRecorderDetail
                    .offset(y: -2)
            } else if showsApplicationPicker {
                applicationPickerDetail
                    .offset(y: -2)
            }
        }
        .frame(height: rowHeight, alignment: .top)
        .onDrag {
            guard !isApplicationPicker else { return NSItemProvider() }
            store.beginDragging(action)
            return NSItemProvider(object: action.id as NSString)
        }
        .onHover { hovered = $0 }
        .onChange(of: store.selectedSlotID) { _, _ in
            showsShortcutRecorder = false
            showsApplicationPicker = false
        }
        .contextMenu {
            if selected {
                Menu("触发方式") {
                    ForEach(RemoteTrigger.allCases) { trigger in
                        Button(trigger.title) {
                            store.selectedTrigger = trigger
                        }
                    }
                }
                Button("测试当前动作") {
                    store.testSelectedAction()
                }
                Divider()
                Button("清除当前分配", role: .destructive) {
                    store.clearSelectedAssignment()
                }
            }
        }
        .help(selected ? "右键可切换触发方式、测试或清除" : action.subtitle)
    }

    private var rowHeight: CGFloat {
        if selected && action.id == "show-actions-ring" { return 165 }
        if showsInlineShortcutRecorder { return ActionLibraryLayoutMetrics.shortcutRecorderRowHeight }
        if showsApplicationPicker { return ActionLibraryLayoutMetrics.applicationPickerRowHeight }
        return rowSelected ? 56 : 37
    }

    private var isRecordedKeyboardShortcut: Bool {
        action.id.hasPrefix("recorded-keyboard-shortcut-")
    }

    private var isKeyboardShortcut: Bool {
        action.id == "keyboard-shortcut" || isRecordedKeyboardShortcut
    }

    private var isApplicationPicker: Bool {
        action.id == chooseApplicationAction.id
    }

    private var showsInlineShortcutRecorder: Bool {
        isKeyboardShortcut && (showsShortcutRecorder || (selected && isRecordedKeyboardShortcut))
    }

    private var rowSelected: Bool {
        selected
            || (action.id == "keyboard-shortcut" && showsShortcutRecorder)
            || (isApplicationPicker && showsApplicationPicker)
    }

    private var usesLatinOpticalScale: Bool {
        action.devicePresentationTitle.unicodeScalars.contains {
            $0.isASCII && CharacterSet.letters.contains($0)
        }
    }

    private var shortcutRecorderDetail: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("支持 ⌘ / ⌥ / ⌃ / ⇧、F1–F20、方向键和导航键。")
                .font(.custom("AvenirNext-Regular", size: 14))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 34, maxHeight: 34, alignment: .topLeading)

            HStack(spacing: 6) {
                ForEach(RemoteTrigger.allCases) { trigger in
                    Button {
                        store.selectedTrigger = trigger
                    } label: {
                        Text(trigger.title)
                            .font(.custom("AvenirNext-Medium", size: 12))
                            .foregroundStyle(
                                store.selectedTrigger == trigger
                                    ? AppTheme.onAccent(for: colorScheme)
                                    : Color.primary.opacity(0.72)
                            )
                            .frame(maxWidth: .infinity, minHeight: 28)
                            .background(
                                store.selectedTrigger == trigger
                                    ? AppTheme.accent(for: colorScheme)
                                    : Color.primary.opacity(0.055)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    .buttonStyle(QuietButtonStyle())
                }
            }

            ShortcutRecorderField(
                displayName: isRecordedKeyboardShortcut ? action.subtitle : "按下按键组合",
                showsPlaceholder: !isRecordedKeyboardShortcut,
                automaticallyActivates: showsShortcutRecorder
            ) { keyCode, flags, displayName in
                store.assignRecordedKeyboardShortcut(
                    keyCode: keyCode,
                    flags: flags,
                    displayName: displayName
                )
                showsShortcutRecorder = false
            }
            .frame(height: 40)
        }
        .padding(.horizontal, 16)
        .padding(.top, ActionLibraryLayoutMetrics.shortcutRecorderTopPadding)
        .padding(.bottom, 14)
        .frame(
            height: ActionLibraryLayoutMetrics.shortcutRecorderDetailHeight,
            alignment: .topLeading
        )
        .background(
            colorScheme == .dark
                ? AppTheme.elevatedSurface(for: colorScheme)
                : Color(white: 240 / 255)
        )
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: 8,
                bottomTrailingRadius: 8,
                style: .continuous
            )
        )
        .padding(.leading, 17)
        .padding(.trailing, 16)
        .accessibilityElement(children: .contain)
    }

    private var applicationPickerDetail: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("选择任意 .app。之后按下“\(store.selectedTrigger.title)”即可启动并切换到该应用。")
                .font(.custom("AvenirNext-Regular", size: 14))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                store.chooseApplicationForSelectedSlot()
            } label: {
                HStack(spacing: 8) {
                    AppIcon(symbol: "app.dashed", size: 17)
                    Text("选择应用程序…")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .frame(
            height: ActionLibraryLayoutMetrics.applicationPickerDetailHeight,
            alignment: .topLeading
        )
        .background(
            colorScheme == .dark
                ? AppTheme.elevatedSurface(for: colorScheme)
                : Color(white: 240 / 255)
        )
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: 8,
                bottomTrailingRadius: 8,
                style: .continuous
            )
        )
        .padding(.leading, 17)
        .padding(.trailing, 16)
        .accessibilityElement(children: .contain)
    }

    private var actionsRingDetail: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Actions Ring 是设备的可自定义数字扩展，让您一键即可访问工具、配置文件等功能。")
                .font(.custom("AvenirNext-Regular", size: 14))
                .lineSpacing(2)
                .frame(height: 40, alignment: .topLeading)
                .offset(
                    x: ActionLibraryLayoutMetrics.actionsRingDescriptionXOffset,
                    y: ActionLibraryLayoutMetrics.actionsRingDescriptionYOffset
                )

            Button("配置 ACTIONS RING") {
                store.showActionsRingFromDeviceDetail()
            }
            .font(.custom("AvenirNext-DemiBold", size: 14))
            .foregroundStyle(AppTheme.accent(for: colorScheme))
            .buttonStyle(QuietButtonStyle())
            .padding(.top, ActionLibraryLayoutMetrics.actionsRingConfigurationTopPadding)
            .offset(x: ActionLibraryLayoutMetrics.actionsRingConfigurationXOffset)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, ActionLibraryLayoutMetrics.actionsRingDetailHorizontalPadding)
        .frame(maxWidth: .infinity, minHeight: 117, maxHeight: 117, alignment: .topLeading)
        .background(
            colorScheme == .dark
                ? AppTheme.elevatedSurface(for: colorScheme)
                : Color(white: 240 / 255)
        )
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: 8,
                bottomTrailingRadius: 8,
                style: .continuous
            )
        )
        .padding(.leading, 17)
        .padding(.trailing, 16)
        .accessibilityElement(children: .contain)
    }
}
