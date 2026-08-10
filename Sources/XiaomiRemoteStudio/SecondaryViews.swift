import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum AutomationFilter: String, CaseIterable, Identifiable {
    case templates
    case actions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .templates: "模板"
        case .actions: "管理"
        }
    }

    var symbol: String {
        switch self {
        case .templates: "rectangle.3.group"
        case .actions: "person"
        }
    }

    static func category(for action: SmartAction) -> String {
        switch action.id {
        case "focus", "meeting", "google-work", "microsoft-work", "web-search", "morning",
             "browser", "notes-app": "生产力"
        case "perplexity", "copilot", "gemini", "ai-reply", "ai-grammar",
             "ai-summary", "ai-translate", "ai-code", "ai-work": "AI"
        case "firefly", "screenshot": "设计师"
        case "netflix", "note", "break", "flights", "shopping", "sports": "休闲"
        case "github", "developer-docs": "开发者"
        default: "休闲"
        }
    }

    static func matches(_ category: String, action: SmartAction) -> Bool {
        switch category {
        case "全部": true
        case "热门": ["focus", "meeting", "note", "netflix", "sports"].contains(action.id)
        case "会议": action.id == "meeting"
        case "开发者": ["browser", "google-work", "github", "developer-docs"].contains(action.id)
        default: self.category(for: action) == category
        }
    }
}

enum AutomationSort: String, CaseIterable, Identifiable {
    case recent
    case name

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: "最近的"
        case .name: "名称"
        }
    }

    func sorted(_ actions: [SmartAction]) -> [SmartAction] {
        switch self {
        case .recent: actions
        case .name:
            actions.sorted {
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        }
    }
}

enum AutomationLibraryLayoutMetrics {
    // Measured from the current Options+ Smart Actions library at 1180 x 760.
    // Keep these values explicit so changes to SwiftUI font metrics do not
    // quietly move the left rail or enlarge the template footer hit target.
    static let sidebarTopInset: CGFloat = 255
    static let sidebarItemSpacing: CGFloat = 10
    static let categorySpacing: CGFloat = 15
    static let categoryHorizontalInset: CGFloat = 13
    static let toolbarImportYOffset: CGFloat = -2.5
    // Retina content captures place the Options+ title ink 5.5 pt lower than
    // SwiftUI's default toolbar alignment. Keep the correction on the shared
    // toolbar so the title and all controls move together.
    static let toolbarYOffset: CGFloat = -1
    static let titleTracking: CGFloat = 1.665
    static let titleXOffset: CGFloat = -0.5
    static let guideTopInset: CGFloat = 6
    static let cardDescriptionTopInset: CGFloat = 8
    static let templateFooterHeight: CGFloat = 56
    static let templateFooterButtonWidth: CGFloat = 100
    static let templateFooterButtonHeight: CGFloat = 48
    static let templateFooterButtonXOffset: CGFloat = -1
    static let templateFooterButtonYOffset: CGFloat = -0.5
    static let emptyIllustrationPlantOffset = CGSize(width: -94, height: 124)
    static let emptyIllustrationOrbOffset = CGSize(width: 151, height: 92)
    static let emptyIllustrationBoxFrontYOffset: CGFloat = 27
    static let emptyIllustrationYOffset: CGFloat = -22
    static let emptyCopyTopInset: CGFloat = 30
    static let emptyIllustrationDiamondSide: CGFloat = 156
    static let emptyIllustrationKeyboardSize = CGSize(width: 93, height: 126)
    static let emptyIllustrationKeyboardOffset = CGSize(width: -21.5, height: 35)
    static let emptyIllustrationMouseSize = CGSize(width: 46, height: 72)
    static let emptyIllustrationMouseOffset = CGSize(width: 50, height: 54)
    static let emptyIllustrationPlantScale = CGSize(width: 0.70, height: 0.95)
    static let emptyIllustrationBoxFlapSize = CGSize(width: 136, height: 46)
    static let emptyIllustrationBoxFrontSize = CGSize(width: 95, height: 62.5)
    static let emptyIllustrationBoxSideSize = CGSize(width: 16, height: 62.5)
    static let emptyIllustrationBoxSideOffset = CGSize(width: 55.5, height: 27)
    static let emptyIllustrationBoxXOffset: CGFloat = 5
    static let emptyIllustrationPlusXOffset: CGFloat = 111
    static let emptyIllustrationPlusYOffset: CGFloat = -65.5
    static let emptyIllustrationOrbSize: CGFloat = 22
    // The current Options+ library opens directly on the filter row: the
    // contextual guide is available from “特性概览”, but it is not a permanent
    // first-screen banner. Keeping it hidden by default removes the measured
    // 94 pt displacement of the filters and card grid while preserving the
    // same on-demand explanation and dismissal interaction.
    static let showsGuideByDefault = false
}

private struct SmartActionEditorRequest: Identifiable {
    let id = UUID()
    let action: SmartAction?
}

struct SmartActionsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var actions: [SmartAction]
    @State private var searchText = ""
    @State private var selection: AutomationFilter
    @State private var selectedCategory = "全部"
    @State private var sortOption: AutomationSort = .recent
    @State private var showsGuide: Bool
    @State private var editorRequest: SmartActionEditorRequest?
    private let usesStoredActions: Bool

    init(
        actions: [SmartAction]? = nil,
        initialSelection: AutomationFilter = .templates,
        showsGuide: Bool = AutomationLibraryLayoutMetrics.showsGuideByDefault
    ) {
        _actions = State(initialValue: actions ?? [])
        _selection = State(initialValue: initialSelection)
        _showsGuide = State(initialValue: showsGuide)
        usesStoredActions = actions == nil
    }

    var body: some View {
        Group {
            if let request = editorRequest {
                SmartActionEditorView(
                    editing: request.action,
                    reservedShortcutBindings: shortcutBindings(excluding: request.action),
                    cancel: { editorRequest = nil },
                    preview: { title, steps in
                        store.previewSmartAction(title: title, steps: steps)
                    },
                    save: saveEditedAction
                )
            } else {
                automationLibrary
            }
        }
    }

    private var automationLibrary: some View {
        VStack(spacing: 0) {
            AutomationToolbar(
                searchText: $searchText,
                importActions: importActions,
                create: { editorRequest = SmartActionEditorRequest(action: nil) }
            )

            HStack(spacing: 0) {
                AutomationSidebar(selection: $selection) {
                    showsGuide = true
                }

                ScrollView {
                    VStack(spacing: 0) {
                        if showsGuide {
                            AutomationGuideBanner(selection: selection) {
                                showsGuide = false
                            }
                            .padding(.top, AutomationLibraryLayoutMetrics.guideTopInset)
                            .offset(x: selection == .templates ? -1 : 0)
                        }

                        if selection == .templates {
                            AutomationTemplateFilters(
                                selectedCategory: $selectedCategory,
                                sortOption: $sortOption
                            )
                                .padding(.top, showsGuide ? 20 : 12)
                                .padding(.bottom, 8)
                                .offset(x: -2, y: -2)
                        } else {
                            AutomationManagementFilters(sortOption: $sortOption)
                                .padding(.top, showsGuide ? 20 : 12)
                                .padding(.bottom, 8)
                                .offset(y: -2)
                        }

                        Group {
                        if selection == .actions && actions.isEmpty {
                            EmptySmartActionsView()
                        } else if filteredActions.isEmpty {
                            EmptyAutomationSearchView {
                                searchText = ""
                            }
                        } else {
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.fixed(260), spacing: 30), count: 3),
                                spacing: 30
                            ) {
                                ForEach(filteredActions) { action in
                                    SmartActionCard(
                                        action: action,
                                            isTemplate: selection == .templates,
                                            templateAdded: selection == .templates
                                            && actions.contains(where: {
                                                $0.actionID == action.actionID
                                            }),
                                        isCustom: selection == .actions,
                                        addTemplate: { addTemplate(action) },
                                        edit: {
                                            editorRequest = SmartActionEditorRequest(action: action)
                                        },
                                        duplicate: { duplicate(action) },
                                        setEnabled: { enabled in
                                            setEnabled(enabled, for: action)
                                        },
                                        export: { exportAction(action) },
                                        delete: { remove(action) }
                                    )
                                }
                            }
                            .frame(width: 840, alignment: .topLeading)
                        }
                        }
                        // The template cards begin 2 pt below the filter row
                        // in the current Options+ build.  A 17 pt inset left
                        // the first card four Retina pixels too low.
                        .padding(.top, selection == .templates ? 15 : 20)
                    }
                    .padding(.bottom, 55)
                    .frame(width: 918, alignment: .top)
                    .offset(x: selection == .templates ? 1 : 0)
                    // Keep the library on the same x origin whether the
                    // vertical scrollbar is present or not. Centering this
                    // fixed-width column made the management tab jump 7 pt
                    // to the right when its contents did not need scrolling.
                    .frame(maxWidth: .infinity, minHeight: 560, alignment: .topLeading)
                }
            }
        }
        .background(AppTheme.canvas(for: colorScheme))
        .overlay(alignment: .bottom) {
            Button {
                guard let url = URL(string: "https://github.com/zhangtuansia/MiCoding/issues/new") else { return }
                NSWorkspace.shared.open(url)
            } label: {
                HStack(spacing: 8) {
                    AppIcon(symbol: "message-square", size: AppIconSize.control)
                    Text("反馈")
                        .font(AppTypography.supportingMedium)
                }
                .foregroundStyle(AppTheme.onAccent(for: colorScheme))
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(Color.black.opacity(colorScheme == .dark ? 0.82 : 0.92))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            .buttonStyle(QuietButtonStyle())
            .padding(.bottom, 1)
            .help("提交 Smart Actions 反馈")
        }
        // The Options+ content capture starts 6 pt above SwiftUI's default
        // placement inside our transparent-titlebar window. Keep the toolbar,
        // guide, sidebar and feedback control on that same measured baseline.
        .offset(y: AutomationLibraryLayoutMetrics.toolbarYOffset)
        .onAppear {
            if usesStoredActions {
                actions = store.smartActions
                if let requestedCategory = store.consumeRequestedAutomationCategory() {
                    selection = .templates
                    selectedCategory = requestedCategory
                }
            }
        }
    }

    private func saveEditedAction(_ action: SmartAction) {
        if let index = actions.firstIndex(where: { $0.id == action.id }) {
            if usesStoredActions {
                actions[index] = store.updateSmartAction(action)
            } else {
                actions[index] = action
            }
        } else {
            if usesStoredActions {
                actions.append(store.addSmartAction(action))
            } else {
                actions.append(action)
            }
        }
        selection = .actions
        editorRequest = nil
    }

    private func shortcutBindings(excluding action: SmartAction?) -> [GlobalShortcutBinding] {
        actions
            .filter { $0.isEnabled && $0.id != action?.id }
            .flatMap { action in
                (action.triggers ?? []).compactMap { trigger in
                    guard case let .shortcut(keyCode, flags, _) = trigger else { return nil }
                    return GlobalShortcutBinding(
                        actionID: action.actionID,
                        keyCode: keyCode,
                        flags: flags
                    )
                }
            }
    }

    private var filteredActions: [SmartAction] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = selection == .templates ? SmartAction.samples : actions
        let filtered = source.filter { action in
            (selection != .templates
                || AutomationFilter.matches(selectedCategory, action: action))
                && (query.isEmpty
                || action.title.localizedCaseInsensitiveContains(query)
                || action.subtitle.localizedCaseInsensitiveContains(query))
        }
        return sortOption.sorted(filtered)
    }

    private func addTemplate(_ action: SmartAction) {
        guard !actions.contains(where: { $0.actionID == action.actionID }) else { return }
        let copiedAction = SmartAction(
            id: UUID().uuidString,
            actionID: action.actionID,
            title: action.title,
            subtitle: action.subtitle,
            symbol: action.symbol,
            tint: action.tint,
            stepCount: action.stepCount,
            stepActionIDs: [action.actionID]
        )
        if usesStoredActions {
            actions.append(store.addSmartAction(copiedAction))
        } else {
            actions.append(copiedAction)
        }
    }

    private func importActions() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "选择从 MiCoding 导出的智能操作 JSON 文件"
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url),
              let imported = try? JSONDecoder().decode([PersistedSmartAction].self, from: data) else {
            return
        }

        for item in imported {
            let collidesWithTemplate = SmartAction.samples.contains(where: { $0.id == item.id })
            let normalizedID = actions.contains(where: { $0.id == item.id }) || collidesWithTemplate
                    ? UUID().uuidString
                    : item.id
            let actionIDCollision = actions.contains(where: { $0.actionID == item.actionID })
            let normalizedActionID = actionIDCollision
                ? "custom-smart-\(UUID().uuidString)"
                : item.actionID
            let normalizedSteps = actionIDCollision
                ? (item.steps
                    ?? item.stepActionIDs?.map(SmartActionStep.action)
                    ?? [.action(item.actionID)])
                : item.steps
            let normalized = PersistedSmartAction(
                id: normalizedID,
                actionID: normalizedActionID,
                title: item.title,
                stepActionIDs: actionIDCollision ? nil : item.stepActionIDs,
                steps: normalizedSteps,
                triggers: item.triggers,
                isEnabled: item.isEnabled
            )
            guard let action = SmartAction.restored(from: normalized) else { continue }
            if usesStoredActions {
                actions.append(store.addSmartAction(action))
            } else {
                actions.append(action)
            }
        }
        selection = .actions
    }

    private func exportAction(_ action: SmartAction) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.message = "导出后可通过 MiCoding 的“导入”按钮恢复此智能操作"

        let safeTitle = action.title
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        panel.nameFieldStringValue = "\(safeTitle.isEmpty ? "MiCoding-Action" : safeTitle).json"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode([action.persistedRepresentation])
            try data.write(to: url, options: .atomic)
            store.showToast("已导出“\(action.title)”")
        } catch {
            store.showToast("导出失败：\(error.localizedDescription)")
        }
    }

    private func duplicate(_ action: SmartAction) {
        let copy = SmartAction(
            id: UUID().uuidString,
            actionID: "custom-smart-\(UUID().uuidString)",
            title: "\(action.title) 副本",
            subtitle: action.subtitle,
            symbol: action.symbol,
            tint: action.tint,
            stepCount: action.stepCount,
            steps: action.steps ?? [.action(action.actionID)],
            triggers: action.triggers,
            // A duplicate can contain the same global shortcut. Keep it off
            // until the user reviews the trigger, matching Logi's draft flow.
            isEnabled: false
        )
        if usesStoredActions {
            actions.append(store.addSmartAction(copy))
        } else {
            actions.append(copy)
        }
    }

    private func setEnabled(_ enabled: Bool, for action: SmartAction) {
        guard let index = actions.firstIndex(where: { $0.id == action.id }) else { return }
        if usesStoredActions,
           !store.setSmartActionEnabled(id: action.id, enabled: enabled) {
            return
        }
        actions[index] = action.withEnabled(enabled)
    }

    private func remove(_ action: SmartAction) {
        actions.removeAll(where: { $0.id == action.id })
        if usesStoredActions {
            store.removeSmartAction(id: action.id)
        }
    }
}

private struct AutomationToolbar: View {
    @Binding var searchText: String
    let importActions: () -> Void
    let create: () -> Void

    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    store.selectSection(.devices)
                } label: {
                    AppIcon(symbol: "arrow.left", size: 22)
                        .frame(width: 47, height: 56)
                }
                .buttonStyle(QuietButtonStyle())
                .help("返回设备")
                .accessibilityLabel("返回设备")

                Text("Smart Actions")
                    .font(AppTypography.latinDisplay)
                    // Brown Pro is slightly wider than the bundled Avenir
                    // fallback. This reproduces the original title advance.
                    .tracking(AutomationLibraryLayoutMetrics.titleTracking)
                    .foregroundStyle(AppTheme.text(for: colorScheme))
                    .offset(x: AutomationLibraryLayoutMetrics.titleXOffset)
                    .frame(width: 320, alignment: .leading)
            }
            .frame(width: 420, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: 9) {
                TextField(
                    "",
                    text: $searchText,
                    prompt: Text("搜索").foregroundStyle(Color.secondary.opacity(0.48))
                )
                    .textFieldStyle(.plain)
                    .font(AppTypography.body)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        AppIcon(symbol: "xmark", size: AppIconSize.control)
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(QuietButtonStyle())
                    .help("清除搜索")
                }

                AppIcon(symbol: "magnifyingglass", size: AppIconSize.control)
                    .foregroundStyle(Color.primary.opacity(0.82))
            }
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .frame(width: 280, height: 50)
            .background(AppTheme.primarySurface(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
            }

            Rectangle()
                .fill(AppTheme.separator(for: colorScheme))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 23)

            Button(action: importActions) {
                HStack(spacing: 9) {
                    AppIcon(symbol: "download", size: 20)
                    Text("导入")
                        .font(AppTypography.bodyBold)
                }
                .frame(width: 90, height: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(QuietButtonStyle())
            .help("导入智能操作")
            .accessibilityRepresentation {
                Button("导入", action: importActions)
            }
            .offset(y: AutomationLibraryLayoutMetrics.toolbarImportYOffset)

            Button(action: create) {
                HStack(spacing: 9) {
                    AppIcon(symbol: "plus", size: 23)
                    Text("创建")
                        .font(AppTypography.bodyBold)
                }
                .foregroundStyle(AppTheme.onAccent(for: colorScheme))
                .frame(width: 88, height: 48)
                .background(AppTheme.accent(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            .buttonStyle(QuietButtonStyle())
            .padding(.leading, 12)
            .offset(y: -2.5)
        }
        .padding(.leading, 40)
        .padding(.trailing, 44)
        .offset(y: -6)
        .frame(height: 87)
        .background(AppTheme.surface(for: colorScheme))
    }
}

private struct AutomationSidebar: View {
    @Binding var selection: AutomationFilter
    let showGuide: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(
                alignment: .leading,
                spacing: AutomationLibraryLayoutMetrics.sidebarItemSpacing
            ) {
                ForEach(AutomationFilter.allCases) { filter in
                    Button {
                        selection = filter
                    } label: {
                        HStack(spacing: 10.5) {
                            if filter == .templates {
                                AutomationTemplateIcon()
                                    .frame(width: 24, height: 24)
                            } else {
                                AutomationManagementIcon()
                                    .frame(width: 24, height: 24)
                            }
                            Text(filter.title)
                                .font(.custom("AvenirNext-Bold", size: 13))
                        }
                        .foregroundStyle(
                            selection == filter
                                ? AppTheme.onAccent(for: colorScheme)
                                : Color.primary
                        )
                        .padding(.leading, 10.5)
                        .frame(width: 86, height: 40, alignment: .leading)
                        .background(
                            selection == filter
                                ? AppTheme.accent(for: colorScheme)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    .buttonStyle(QuietButtonStyle())
                    // Use the full visual bounds as the accessibility target
                    // and expose an explicit hint/value. Some macOS SwiftUI
                    // releases omit AXTitle for custom button labels, even
                    // when the visible text is present.
                    .accessibilityRepresentation {
                        Button(filter.title) {
                            selection = filter
                        }
                        .accessibilityValue(selection == filter ? "已选择" : "未选择")
                        .accessibilityHint("打开(filter.title)页")
                        .accessibilityAddTraits(selection == filter ? .isSelected : [])
                    }
                }
            }
            .padding(.top, AutomationLibraryLayoutMetrics.sidebarTopInset)

            Spacer()

            Button(action: showGuide) {
                Text("特性概览")
                    .font(.custom("AvenirNext-Bold", size: 14))
                    .foregroundStyle(AppTheme.accent(for: colorScheme))
                    .frame(height: 26)
            }
            .buttonStyle(QuietButtonStyle())
            .help("重新显示模板使用说明")
            .padding(.bottom, 30)
        }
        .padding(.leading, 50)
        .frame(width: 250, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.canvas(for: colorScheme))
    }
}

private struct AutomationTemplateIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 1.8, style: .continuous)
                .stroke(lineWidth: 1.8)
                .frame(width: 17, height: 21)

            VStack(spacing: 3) {
                HStack(spacing: 2.5) {
                    Circle()
                        .frame(width: 2.5, height: 2.5)
                    Capsule()
                        .frame(width: 7, height: 2)
                }
                Capsule()
                    .frame(width: 11.5, height: 2)
            }
        }
    }
}

private struct AutomationManagementIcon: View {
    var body: some View {
        Canvas { context, size in
            let scaleX = size.width / 24
            let scaleY = size.height / 24

            let hook = Path(
                ellipseIn: CGRect(
                    x: 5 * scaleX,
                    y: 2 * scaleY,
                    width: 5.5 * scaleX,
                    height: 5.5 * scaleY
                )
            )

            var hanger = Path()
            hanger.move(to: CGPoint(x: 9.5 * scaleX, y: 7 * scaleY))
            hanger.addLine(to: CGPoint(x: 12 * scaleX, y: 9 * scaleY))
            hanger.addLine(to: CGPoint(x: 4.5 * scaleX, y: 15.5 * scaleY))
            hanger.addCurve(
                to: CGPoint(x: 19.5 * scaleX, y: 15.5 * scaleY),
                control1: CGPoint(x: 8 * scaleX, y: 17.5 * scaleY),
                control2: CGPoint(x: 16 * scaleX, y: 17.5 * scaleY)
            )
            hanger.addLine(to: CGPoint(x: 12 * scaleX, y: 9 * scaleY))

            var base = Path()
            base.move(to: CGPoint(x: 2 * scaleX, y: 19 * scaleY))
            base.addLine(to: CGPoint(x: 22 * scaleX, y: 19 * scaleY))

            let stroke = StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
            context.stroke(hook, with: .foreground, style: stroke)
            context.stroke(hanger, with: .foreground, style: stroke)
            context.stroke(base, with: .foreground, style: stroke)
        }
    }
}

private struct AutomationGuideBanner: View {
    let selection: AutomationFilter
    let dismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Text(message)
                .font(AppTypography.body)
                // Brown Pro has a slightly tighter CJK fallback than Avenir
                // Next. This optical correction preserves the reference line
                // break after “设备，即” inside the fixed 840 pt banner.
                .tracking(selection == .templates ? -0.35 : -0.10)
                .foregroundStyle(AppTheme.onAccent(for: colorScheme))
                .lineSpacing(1.5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 54)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(y: 3)

            Button(action: dismiss) {
                AppIcon(symbol: "xmark", size: AppIconSize.control)
                    .foregroundStyle(AppTheme.onAccent(for: colorScheme))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(QuietButtonStyle())
            .help("关闭提示")
        }
        .padding(.leading, 30)
        .padding(.trailing, 12)
        .padding(.top, 17)
        .frame(width: 840, height: selection == .templates ? 80 : 100, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: 9.5, style: .continuous)
                .fill(AppTheme.accent(for: colorScheme))
                .offset(y: -2)
        }
    }

    private var message: String {
        switch selection {
        case .templates:
            "在此选项卡上，您可以找到我们为您创建的 Smart Actions 模板。只需选择其中之一，按下“获取”，将其分配至您的设备，即可开始使用！安装后，您可以按原设计使用，也可以根据需要自定义操作。"
        case .actions:
            "在此选项卡上，可以看到您的 Smart Actions。您可以从可用模板中添加 Smart Actions，也可以使用“创建”按钮从头开始创建新模板。自由测试组合 Smart Actions，从而满足您的需求。您可以使用“导出/导入为文件”功能与朋友和同事分享您创建的 Smart Actions。"
        }
    }
}

private struct AutomationManagementFilters: View {
    @Binding var sortOption: AutomationSort

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            Text("全部")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppTheme.onAccent(for: colorScheme))
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(AppTheme.accent(for: colorScheme))
                .clipShape(Capsule())

            Spacer()

            AppIcon(symbol: "list-filter", size: AppIconSize.navigation)
                .frame(width: 32, height: 32)
                .padding(.trailing, 19)
                .help("管理标签")

            AutomationSortMenu(sortOption: $sortOption)
        }
        .frame(width: 840, height: 48)
    }
}

private struct AutomationSortMenu: View {
    @Binding var sortOption: AutomationSort

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Menu {
            ForEach(AutomationSort.allCases) { option in
                Button {
                    sortOption = option
                } label: {
                    if sortOption == option {
                        Label(option.title, systemImage: "checkmark")
                    } else {
                        Text(option.title)
                    }
                }
            }
        } label: {
            Color.clear
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 166, height: 48)
        .overlay(alignment: .leading) {
            Text(sortOption.title)
                .font(.custom("AvenirNext-Bold", size: 14))
                .padding(.leading, 16)
                .offset(y: 3.5)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .trailing) {
            AppIcon(symbol: "chevron.down", size: AppIconSize.indicator)
                .padding(.trailing, 25)
                .allowsHitTesting(false)
        }
        .background(AppTheme.primarySurface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(AppTheme.controlBorder(for: colorScheme), lineWidth: 1)
        }
    }
}

private struct AutomationTemplateFilters: View {
    @Binding var selectedCategory: String
    @Binding var sortOption: AutomationSort

    @Environment(\.colorScheme) private var colorScheme
    private let categories = ["全部", "热门", "生产力", "会议", "AI", "休闲", "设计师", "开发者"]

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: AutomationLibraryLayoutMetrics.categorySpacing) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category)
                            .font(AppTypography.body)
                            .foregroundStyle(
                                selectedCategory == category
                                    ? AppTheme.onAccent(for: colorScheme)
                                    : Color.primary
                            )
                            .padding(
                                .horizontal,
                                AutomationLibraryLayoutMetrics.categoryHorizontalInset
                            )
                            .frame(height: 32)
                            .background(
                                selectedCategory == category
                                    ? AppTheme.accent(for: colorScheme)
                                    : Color.clear
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(QuietButtonStyle())
                    .offset(x: centerCorrection(for: category))
                }
            }
            .frame(width: 622, alignment: .leading)

            Spacer(minLength: 32)

            Menu {
                ForEach(AutomationSort.allCases) { option in
                    Button {
                        sortOption = option
                    } label: {
                        if sortOption == option {
                            Label(option.title, systemImage: "checkmark")
                        } else {
                            Text(option.title)
                        }
                    }
                }
            } label: {
                Color.clear
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 166, height: 48)
            .overlay(alignment: .leading) {
                Text(sortOption.title)
                    .font(.custom("AvenirNext-Bold", size: 14))
                    .padding(.leading, 16)
                    .offset(y: 3.5)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .trailing) {
                AppIcon(symbol: "chevron.down", size: AppIconSize.indicator)
                    .padding(.trailing, 25)
                    .allowsHitTesting(false)
            }
            .background(AppTheme.primarySurface(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(AppTheme.controlBorder(for: colorScheme), lineWidth: 1)
            }
            .offset(x: 1)
        }
        .frame(width: 840, height: 48)
    }

    private func centerCorrection(for category: String) -> CGFloat {
        switch category {
        case "全部", "热门", "生产力", "会议", "AI": 1
        case "休闲", "设计师", "开发者": 0.5
        default: 0.5
        }
    }
}

private struct SmartActionCard: View {
    let action: SmartAction
    let isTemplate: Bool
    let templateAdded: Bool
    let isCustom: Bool
    let addTemplate: () -> Void
    let edit: () -> Void
    let duplicate: () -> Void
    let setEnabled: (Bool) -> Void
    let export: () -> Void
    let delete: () -> Void

    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var didRun = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                ForEach(Array(stepVisuals.enumerated()), id: \.offset) { _, visual in
                    AutomationStepIcon(visual: visual)
                }
                Spacer(minLength: 0)

                if !isTemplate {
                    Menu {
                        Button("运行") { run() }
                        Button("分配给按键") { store.beginAssigningSmartAction(action) }

                        if isCustom {
                            Divider()
                            Button("重命名和编辑", action: edit)
                            Button("创建副本", action: duplicate)
                            Button("导出", action: export)
                            Button("删除", role: .destructive, action: delete)
                        } else {
                            Button("导出", action: export)
                        }
                    } label: {
                        AppIcon(symbol: "ellipsis", size: 16)
                            .foregroundStyle(Color.primary.opacity(0.82))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help(isCustom ? "更多操作：编辑、复制、导出或删除" : "更多操作：运行、分配或导出")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 6)
            .frame(height: 58, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 0) {
                AppTypography.smartActionTitleText(action.title)
                    .tracking(-0.30)
                    .foregroundStyle(cardForeground)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
                    .offset(y: 1)

                AppTypography.smartActionDescriptionText(action.subtitle)
                    .foregroundStyle(cardForeground)
                    .lineLimit(4)
                    .lineSpacing(2)
                    .padding(.top, AutomationLibraryLayoutMetrics.cardDescriptionTopInset)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 2)
            .frame(
                maxWidth: .infinity,
                minHeight: isTemplate ? 165.5 : 205,
                maxHeight: isTemplate ? 165.5 : 205,
                alignment: .topLeading
            )

            if isTemplate {
                HStack {
                    Text(AutomationFilter.category(for: action))
                        .font(AppTypography.supporting)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(Color.primary.opacity(0.055))
                        .clipShape(Capsule())
                    Spacer()
                }
                .padding(.horizontal, 20)
                .frame(height: 38.5)
            }

            Rectangle()
                .fill(AppTheme.controlBorder(for: colorScheme))
                .frame(height: 1)

            if isTemplate {
                ZStack {
                    cardFooterBackground

                    Button(action: addTemplate) {
                        Text(templateAdded ? "已添加" : "添加")
                            .font(AppTypography.bodyBold)
                            .foregroundStyle(
                                templateAdded
                                    ? AppTheme.success
                                    : AppTheme.accent(for: colorScheme)
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(QuietButtonStyle())
                    .frame(
                        width: AutomationLibraryLayoutMetrics.templateFooterButtonWidth,
                        height: AutomationLibraryLayoutMetrics.templateFooterButtonHeight
                    )
                    .contentShape(Rectangle())
                    .disabled(templateAdded)
                    .help(templateAdded ? "已添加\(action.title)" : "添加\(action.title)")
                    .accessibilityRepresentation {
                        Button(templateAdded ? "已添加" : "添加", action: addTemplate)
                            .disabled(templateAdded)
                    }
                    .offset(
                        x: AutomationLibraryLayoutMetrics.templateFooterButtonXOffset,
                        y: AutomationLibraryLayoutMetrics.templateFooterButtonYOffset
                    )
                }
                .frame(height: AutomationLibraryLayoutMetrics.templateFooterHeight)
            } else {
                HStack(spacing: 10) {
                    Button(action: run) {
                        HStack(spacing: 7) {
                            AppIcon(
                                symbol: didRun ? "checkmark" : "play.fill",
                                size: AppIconSize.indicator
                            )
                            Text(didRun ? "已运行" : "试运行")
                                .font(AppTypography.supportingMedium)
                        }
                        .foregroundStyle(didRun ? AppTheme.success : AppTheme.accent(for: colorScheme))
                    }
                    .buttonStyle(QuietButtonStyle())
                    .help("试运行\(action.title)")

                    Spacer()

                    Text(action.isEnabled ? "有效" : "已停用")
                        .font(AppTypography.supportingMedium)
                        .foregroundStyle(action.isEnabled ? Color.primary : Color.secondary)

                    Button {
                        setEnabled(!action.isEnabled)
                    } label: {
                        ZStack(alignment: action.isEnabled ? .trailing : .leading) {
                            Capsule()
                                .fill(
                                    action.isEnabled
                                        ? AppTheme.accent(for: colorScheme)
                                        : Color.secondary.opacity(0.30)
                                )
                            Circle()
                                .fill(.white)
                                .padding(2)
                                .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
                        }
                        .frame(width: 30, height: 18)
                    }
                    .buttonStyle(QuietButtonStyle())
                    .help(action.isEnabled ? "停用此 Smart Action" : "启用此 Smart Action")
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    (didRun ? AppTheme.success : AppTheme.accent(for: colorScheme))
                        .opacity(didRun ? 0.075 : 0)
                )
            }
        }
        .background(cardBodyBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.radiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppMetrics.radiusSmall, style: .continuous)
                .stroke(AppTheme.controlBorder(for: colorScheme), lineWidth: 1)
        }
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.14 : 0.10),
            radius: 10,
            x: 4,
            y: 4
        )
        .frame(width: 260, height: 320)
        .contextMenu {
            if !isTemplate {
                Button("运行") { run() }
                Button("分配给按键") { store.beginAssigningSmartAction(action) }
                if isCustom {
                    Divider()
                    Button("重命名和编辑", action: edit)
                    Button("创建副本", action: duplicate)
                    Button("导出", action: export)
                    Button("删除", role: .destructive, action: delete)
                } else {
                    Button("导出", action: export)
                }
            }
        }
    }

    private var stepVisuals: [AutomationStepVisual] {
        if let steps = action.steps,
           steps != [.action(action.actionID)] {
            var visuals: [AutomationStepVisual] = [.symbol("keyboard"), .separator]
            visuals.append(contentsOf: steps.prefix(4).map { step in
                .symbol(step.symbol)
            })
            if steps.count > 4 {
                visuals.append(.label("+\(steps.count - 4)"))
            }
            return visuals
        }

        let chrome = "/Applications/Google Chrome.app"
        return switch action.actionID {
        case "smart-focus": [
            .symbol("keyboard"),
            .separator,
            .application(chrome),
            .application(chrome),
            .symbol("pencil"),
            .label("+5")
        ]
        case "smart-meeting": [
            .symbol("keyboard"),
            .separator,
            .symbol("panel-top"),
            .application("/System/Applications/Notes.app"),
            .symbol("settings")
        ]
        case "smart-note": [
            .symbol("keyboard"),
            .separator,
            .application(chrome),
            .application(chrome),
            .symbol("pencil"),
            .label("+16")
        ]
        case "smart-netflix": [
            .symbol("keyboard"),
            .separator,
            .application(chrome),
            .application(chrome),
            .symbol("pencil"),
            .label("+3")
        ]
        case "smart-google-work": [
            .symbol("keyboard"),
            .separator,
            .application(chrome),
            .application(chrome),
            .symbol("pencil"),
            .label("+15")
        ]
        case "smart-microsoft-work": [
            .symbol("keyboard"),
            .separator,
            .symbol("panel-top"),
            .symbol("panel-top"),
            .symbol("panel-top")
        ]
        case "smart-browser": [
            .symbol("keyboard"),
            .separator,
            .application(chrome),
            .symbol("pencil"),
            .label("+3")
        ]
        case "smart-screenshot": [
            .symbol("keyboard"),
            .separator,
            .application(chrome),
            .symbol("scan"),
            .label("+15")
        ]
        case "smart-notes-app": [
            .symbol("keyboard"),
            .separator,
            .symbol("panel-top"),
            .symbol("panel-top"),
            .symbol("panel-top")
        ]
        case "smart-ai-work": [
            .symbol("keyboard"),
            .separator,
            .application(chrome),
            .symbol("sparkles")
        ]
        case "smart-web-search": [
            .symbol("keyboard"),
            .separator,
            .application(chrome),
            .application(chrome),
            .symbol("pencil"),
            .label("+4")
        ]
        case "smart-break": [
            .symbol("keyboard"),
            .separator,
            .application(chrome),
            .application(chrome),
            .symbol("pencil"),
            .label("+14")
        ]
        case "smart-flights": [
            .symbol("keyboard"),
            .separator,
            .application(chrome),
            .symbol("pencil"),
            .label("+3")
        ]
        case "smart-shopping": [
            .symbol("keyboard"),
            .separator,
            .application(chrome),
            .symbol("pencil"),
            .label("+11")
        ]
        case "smart-perplexity": [
            .symbol("keyboard"),
            .separator,
            .application(chrome),
            .symbol("sparkles"),
            .label("+5")
        ]
        case "smart-firefly", "smart-copilot", "smart-gemini": [
            .symbol("keyboard"),
            .separator,
            .application(chrome),
            .symbol("sparkles"),
            .label("+3")
        ]
        case "smart-ai-reply", "smart-ai-grammar", "smart-ai-summary",
             "smart-ai-translate", "smart-ai-code": [
            .symbol("keyboard"),
            .separator,
            .application(chrome),
            .symbol("sparkles"),
            .label("+7")
        ]
        case "smart-morning": [
            .symbol("keyboard"),
            .separator,
            .symbol("panel-top"),
            .application("/System/Applications/Notes.app"),
            .application(chrome)
        ]
        case "smart-sports", "smart-github", "smart-developer-docs": [
            .symbol("keyboard"),
            .separator,
            .application(chrome),
            .symbol("pencil"),
            .label("+3")
        ]
        default: [.symbol(action.symbol)]
        }
    }

    private var cardForeground: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var cardBodyBackground: Color {
        colorScheme == .dark ? .black : AppTheme.surface(for: colorScheme)
    }

    private var cardFooterBackground: Color {
        colorScheme == .dark ? Color(white: 15 / 255) : AppTheme.surface(for: colorScheme)
    }

    private func run() {
        didRun = true
        store.runAction(actionID: action.actionID, title: action.title)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            didRun = false
        }
    }
}

private enum AutomationStepVisual {
    case application(String)
    case symbol(String)
    case separator
    case label(String)
}

private struct AutomationStepIcon: View {
    let visual: AutomationStepVisual

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            switch visual {
            case let .application(path):
                if let icon = Self.applicationIcon(at: path) {
                    if path.contains("Google Chrome.app") || path.contains("Safari.app") {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .antialiased(true)
                            .scaledToFit()
                            .scaleEffect(1.16)
                            .clipShape(Circle())
                    } else {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .antialiased(true)
                            .scaledToFit()
                    }
                }
            case let .symbol(symbol):
                AppIcon(symbol: symbol, size: AppIconSize.row)
                    .foregroundStyle(iconForeground.opacity(0.95))
            case .separator:
                Rectangle()
                    .fill(iconForeground.opacity(0.42))
                    .frame(width: 2, height: 20)
            case let .label(text):
                Text(text)
                    .font(AppTypography.supportingMedium)
                    .foregroundStyle(iconForeground.opacity(0.95))
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }

    private var iconForeground: Color {
        colorScheme == .dark ? .white : .primary
    }

    private static let applicationIconCache = NSCache<NSString, NSImage>()

    private static func applicationIcon(at path: String) -> NSImage? {
        let key = path as NSString
        if let cached = applicationIconCache.object(forKey: key) {
            return cached
        }
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: path)
        applicationIconCache.setObject(icon, forKey: key)
        return icon
    }
}

enum SmartActionEditorLayoutMetrics {
    static let headerHeight: CGFloat = 80
    // Options+ renders its 33 pt icon-font back glyph at roughly 16 x 12 pt.
    // Lucide's 24 pt arrow paints wider, so compress its vertical stroke to
    // preserve the reference glyph's optical proportions.
    static let backArrowSize: CGFloat = 24
    static let backArrowVerticalScale: CGFloat = 0.76
    static let columnWidth: CGFloat = 500
    static let sectionTitleHeight: CGFloat = 48
    static let sectionGap: CGFloat = 32
    static let fieldRowHeight: CGFloat = 56
    static let emptyFieldHeight: CGFloat = 48
    static let sequenceBadgeSize: CGFloat = 40
    static let contentBottomInset: CGFloat = 40
    static let footerLeadingInset: CGFloat = 33
    static let footerTrailingInset: CGFloat = 25
    static let footerBottomInset: CGFloat = 40
    static let controlWidth: CGFloat = 170
    static let controlHeight: CGFloat = 40
}

struct SmartActionEditorView: View {
    let editing: SmartAction?
    let reservedShortcutBindings: [GlobalShortcutBinding]
    let cancel: () -> Void
    let preview: (String, [SmartActionStep]) -> Void
    let save: (SmartAction) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var title: String
    @State private var steps: [SmartActionStep]
    @State private var triggers: [SmartActionTrigger]
    @State private var showsTriggerMenu = false
    @State private var showsActionMenu = false
    @State private var showsAIPromptActions = false
    @State private var showsSystemActions = false
    @State private var selectedStepIndex: Int?
    @State private var selectedTriggerIndex: Int?
    @State private var draggingStepIndex: Int?
    @State private var hoveredStepIndex: Int?
    @State private var hoveredTriggerIndex: Int?

    init(
        editing: SmartAction? = nil,
        reservedShortcutBindings: [GlobalShortcutBinding] = [],
        initialTriggerMenuOpen: Bool = false,
        initialActionMenuOpen: Bool = false,
        initialSelectedStepIndex: Int? = nil,
        initialSelectedTriggerIndex: Int? = nil,
        cancel: @escaping () -> Void = {},
        preview: @escaping (String, [SmartActionStep]) -> Void = { _, _ in },
        save: @escaping (SmartAction) -> Void
    ) {
        self.editing = editing
        self.reservedShortcutBindings = reservedShortcutBindings
        self.cancel = cancel
        self.preview = preview
        self.save = save
        _title = State(initialValue: editing?.title ?? "")
        _steps = State(
            initialValue: editing?.steps
                ?? editing.map { [.action($0.actionID)] }
                ?? []
        )
        _triggers = State(
            initialValue: editing?.triggers
                ?? (editing == nil ? [] : [.device])
        )
        _showsTriggerMenu = State(initialValue: initialTriggerMenuOpen)
        _showsActionMenu = State(initialValue: initialActionMenuOpen)
        _selectedStepIndex = State(initialValue: initialSelectedStepIndex)
        _selectedTriggerIndex = State(initialValue: initialSelectedTriggerIndex)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.canvas(for: colorScheme)

            VStack(spacing: 0) {
                editorHeader

                GeometryReader { geometry in
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                workflowSectionTitle("如果…")
                                triggerPanel

                                workflowSectionTitle("那么…")
                                    .padding(.top, SmartActionEditorLayoutMetrics.sectionGap)
                                actionPanel

                                Color.clear
                                    .frame(height: 1)
                                    .id("workflow-editor-bottom")
                            }
                            .frame(width: SmartActionEditorLayoutMetrics.columnWidth)
                            // Options+ vertically centers the workflow in the
                            // space below its fixed 80 pt header, while keeping
                            // a 40 pt clear area above the fixed controls.
                            .frame(
                                minHeight: max(
                                    0,
                                    geometry.size.height
                                        - SmartActionEditorLayoutMetrics.contentBottomInset
                                ),
                                alignment: .center
                            )
                            .padding(.bottom, SmartActionEditorLayoutMetrics.contentBottomInset)
                            .frame(maxWidth: .infinity)
                        }
                        .onAppear {
                            guard showsActionMenu else { return }
                            DispatchQueue.main.async {
                                proxy.scrollTo("workflow-editor-bottom", anchor: .bottom)
                            }
                        }
                        .onChange(of: showsActionMenu) { _, isOpen in
                            guard isOpen else { return }
                            withAnimation(.easeOut(duration: 0.22)) {
                                proxy.scrollTo("workflow-editor-bottom", anchor: .bottom)
                            }
                        }
                    }
                }
            }

            editorFooter
        }
    }

    private var editorHeader: some View {
        HStack(spacing: 0) {
            Button(action: cancel) {
                AppIcon(symbol: "arrow.left", size: SmartActionEditorLayoutMetrics.backArrowSize)
                    .scaleEffect(
                        x: 1,
                        y: SmartActionEditorLayoutMetrics.backArrowVerticalScale
                    )
                    .offset(x: -0.5, y: 1.5)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(QuietButtonStyle())
            .accessibilityLabel("返回 Smart Actions")

            TextField("新建智能操作", text: $title)
                .textFieldStyle(.plain)
                .font(.custom("AvenirNext-Bold", size: 31))
                .tracking(-0.2)
                .frame(maxWidth: 600)

            Spacer()
        }
        .padding(.horizontal, 40)
        .frame(height: SmartActionEditorLayoutMetrics.headerHeight)
        .background(AppTheme.canvas(for: colorScheme))
    }

    private func workflowSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.custom("AvenirNext-Bold", size: 20))
            .padding(.leading, 20)
            .frame(
                maxWidth: .infinity,
                minHeight: SmartActionEditorLayoutMetrics.sectionTitleHeight,
                maxHeight: SmartActionEditorLayoutMetrics.sectionTitleHeight,
                alignment: .leading
            )
    }

    @ViewBuilder
    private var triggerPanel: some View {
        if showsTriggerMenu {
            VStack(spacing: 0) {
                workflowMenuHeader("添加触发器")
                workflowMenuRow(symbol: "app.dashed", title: "应用", enabled: true) {
                    chooseTriggerApplication()
                }
                workflowMenuRow(
                    symbol: "av.remote",
                    title: "设备",
                    enabled: !triggers.contains(.device)
                ) {
                    triggers.append(.device)
                    showsTriggerMenu = false
                }
                // Keep the category rail structurally identical to Options+.
                // These triggers depend on Logitech-specific host services,
                // so expose them honestly as unavailable instead of silently
                // removing two rows and shrinking the menu.
                workflowMenuRow(symbol: "calculator", title: "控制台", enabled: false) {}
                workflowMenuRow(
                    symbol: "circle-dot",
                    title: "Actions Ring",
                    enabled: !triggers.contains(.actionsRing)
                ) {
                    triggers.append(.actionsRing)
                    showsTriggerMenu = false
                }
                workflowMenuRow(symbol: "gearshape", title: "系统", enabled: false) {}
                workflowMenuRow(symbol: "keyboard", title: "快捷键", enabled: true) {
                    triggers.append(
                        .shortcut(
                            keyCode: 15,
                            flags: UInt64((1 << 17) | (1 << 20)),
                            name: "⇧⌘R"
                        )
                    )
                    selectedTriggerIndex = triggers.count - 1
                    showsTriggerMenu = false
                }
            }
            .workflowPanel(colorScheme: colorScheme)
        } else if !triggers.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(triggers.enumerated()), id: \.offset) { index, trigger in
                    let hasShortcutConflict = triggerHasShortcutConflict(at: index)
                    HStack(spacing: 0) {
                        sequenceBadge(number: index + 1, selected: false)
                        AppIcon(symbol: trigger.symbol, size: 24)
                            .foregroundStyle(AppTheme.accent(for: colorScheme))
                            .frame(width: 24, height: 24)
                            .padding(.leading, 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(trigger.title)
                                .font(AppTypography.bodyBold)
                            Text(trigger.subtitle)
                                .font(AppTypography.supporting)
                                .foregroundStyle(hasShortcutConflict ? Color.red : .secondary)
                        }
                        .padding(.leading, 13)
                        Spacer()
                        Button {
                            triggers.remove(at: index)
                            selectedTriggerIndex = nil
                        } label: {
                            AppIcon(symbol: "xmark", size: AppIconSize.control)
                                .frame(width: 55, height: SmartActionEditorLayoutMetrics.fieldRowHeight)
                        }
                        .buttonStyle(QuietButtonStyle())
                        .opacity(hoveredTriggerIndex == index ? 1 : 0)
                        .accessibilityLabel("删除触发器：\(trigger.title)")
                    }
                    .padding(.leading, 20)
                    .frame(height: SmartActionEditorLayoutMetrics.fieldRowHeight)
                    .background(
                        hasShortcutConflict
                            ? Color.red.opacity(colorScheme == .dark ? 0.10 : 0.055)
                            : selectedTriggerIndex == index
                                ? AppTheme.accent(for: colorScheme).opacity(0.055)
                                : Color.clear
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTriggerIndex = trigger.isShortcut
                            ? (selectedTriggerIndex == index ? nil : index)
                            : nil
                    }
                    .onHover { isHovering in
                        hoveredTriggerIndex = isHovering ? index : nil
                    }

                    if selectedTriggerIndex == index,
                       case let .shortcut(_, _, name) = trigger {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("点按下方区域，然后输入新的全局快捷键。")
                                .font(AppTypography.supporting)
                                .foregroundStyle(.secondary)
                            ShortcutRecorderField(displayName: name) { keyCode, flags, displayName in
                                triggers[index] = .shortcut(
                                    keyCode: keyCode,
                                    flags: flags,
                                    name: displayName
                                )
                            }
                            .frame(height: 38)
                            if !triggers[index].isValid {
                                Text("为避免误触，快捷键必须包含至少一个修饰键。")
                                    .font(AppTypography.supporting)
                                    .foregroundStyle(Color.red)
                            } else if hasShortcutConflict {
                                Text("此全局快捷键已用于另一项 Smart Action。")
                                    .font(AppTypography.supporting)
                                    .foregroundStyle(Color.red)
                            }
                        }
                        .padding(.horizontal, 68)
                        .padding(.vertical, 12)
                        .background(AppTheme.accent(for: colorScheme).opacity(0.035))
                    }
                }
                Button {
                    showsTriggerMenu = true
                    selectedTriggerIndex = nil
                } label: {
                    Text("添加触发器")
                        .font(AppTypography.bodyBold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .frame(height: SmartActionEditorLayoutMetrics.emptyFieldHeight)
                }
                .buttonStyle(QuietButtonStyle())
            }
            .workflowPanel(colorScheme: colorScheme)
        } else {
            Button {
                showsTriggerMenu = true
            } label: {
                Text("添加触发器")
                    .font(AppTypography.bodyBold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .frame(height: SmartActionEditorLayoutMetrics.emptyFieldHeight)
            }
            .buttonStyle(QuietButtonStyle())
            .workflowPanel(colorScheme: colorScheme)
        }
    }

    private var actionPanel: some View {
        VStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                workflowStep(step, at: index)
                if selectedStepIndex == index, stepNeedsConfiguration(step) {
                    stepConfiguration(step, at: index)
                }
            }

            if showsActionMenu {
                actionMenu
            } else {
                Button {
                    showsActionMenu = true
                    selectedStepIndex = nil
                } label: {
                    Text("添加动作")
                        .font(AppTypography.bodyBold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .frame(height: SmartActionEditorLayoutMetrics.emptyFieldHeight)
                }
                .buttonStyle(QuietButtonStyle())
            }
        }
        .workflowPanel(colorScheme: colorScheme)
    }

    private func workflowStep(_ step: SmartActionStep, at index: Int) -> some View {
        let selected = selectedStepIndex == index
        let interactive = selected || hoveredStepIndex == index
        let invalid = !step.isValid
        return HStack(spacing: 0) {
            if interactive {
                AppIcon(symbol: "grip-vertical", size: 18)
                    .foregroundStyle(AppTheme.accent(for: colorScheme))
                    .frame(
                        width: SmartActionEditorLayoutMetrics.sequenceBadgeSize,
                        height: SmartActionEditorLayoutMetrics.sequenceBadgeSize
                    )
                    .background(AppTheme.surface(for: colorScheme))
                    .clipShape(Circle())
            } else {
                sequenceBadge(number: index + 1, selected: false)
            }

            AppIcon(symbol: step.symbol, size: 24)
                .foregroundStyle(step.tint)
                .frame(width: 24, height: 24)
                .padding(.leading, 10)

            Text(step.title)
                .font(AppTypography.bodyBold)
                .lineLimit(1)
                .padding(.leading, 13)

            Spacer(minLength: 8)

            if interactive {
                Button {
                    steps.remove(at: index)
                    selectedStepIndex = nil
                } label: {
                    AppIcon(symbol: "xmark", size: AppIconSize.control)
                        .foregroundStyle(AppTheme.accent(for: colorScheme))
                        .frame(width: 55, height: SmartActionEditorLayoutMetrics.fieldRowHeight)
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityLabel("删除动作：\(step.title)")
            }
        }
        .padding(.leading, 20)
        .frame(height: SmartActionEditorLayoutMetrics.fieldRowHeight)
        .background(
            invalid
                ? Color.red.opacity(colorScheme == .dark ? 0.10 : 0.055)
                : selected
                    ? AppTheme.accent(for: colorScheme).opacity(0.055)
                    : Color.clear
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedStepIndex = selected ? nil : index
            showsActionMenu = false
        }
        .onHover { isHovering in
            hoveredStepIndex = isHovering ? index : nil
        }
        .onDrag {
            draggingStepIndex = index
            return NSItemProvider(object: String(index) as NSString)
        }
        .onDrop(
            of: [.text],
            delegate: SmartActionStepDropDelegate(
                destinationIndex: index,
                steps: $steps,
                draggingIndex: $draggingStepIndex,
                selectedIndex: $selectedStepIndex
            )
        )
    }

    @ViewBuilder
    private func stepConfiguration(_ step: SmartActionStep, at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            switch step {
            case .action:
                EmptyView()
            case let .application(bundleIdentifier, name):
                applicationConfiguration(
                    bundleIdentifier: bundleIdentifier,
                    name: name,
                    operation: .open,
                    at: index
                )
            case let .applicationPath(path, name):
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(AppTypography.bodyMedium)
                        Text(path)
                            .font(AppTypography.supporting)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text("打开并切换到所选应用")
                            .font(AppTypography.supporting)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("更换应用") { chooseApplication(replacing: index) }
                        .buttonStyle(InlineActionButtonStyle())
                }
            case let .applicationControl(bundleIdentifier, name, operation):
                applicationConfiguration(
                    bundleIdentifier: bundleIdentifier,
                    name: name,
                    operation: operation,
                    at: index
                )
            case let .keystroke(_, _, name):
                Text("点按下方区域，然后输入新的快捷键。当前：\(name)")
                    .font(AppTypography.supporting)
                    .foregroundStyle(.secondary)
                ShortcutRecorderField(displayName: name) { keyCode, flags, displayName in
                    steps[index] = .keystroke(
                        keyCode: keyCode,
                        flags: flags,
                        name: displayName
                    )
                }
                .frame(height: 38)
            case let .text(value):
                TextEditor(text: textBinding(at: index, value: value))
                    .font(AppTypography.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(height: 84)
                    .background(AppTheme.surface(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(
                                step.isValid ? AppTheme.separator(for: colorScheme) : Color.red,
                                lineWidth: 1
                            )
                    }
                Text("\(value.count) / 1000")
                    .font(AppTypography.supporting)
                    .foregroundStyle(value.count > 1000 ? Color.red : .secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            case let .url(value):
                TextField("https://example.com", text: urlBinding(at: index, value: value))
                    .textFieldStyle(.plain)
                    .font(AppTypography.body)
                    .padding(.horizontal, 10)
                    .frame(height: 38)
                    .background(AppTheme.surface(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(
                                step.isValid ? AppTheme.separator(for: colorScheme) : Color.red,
                                lineWidth: 1
                            )
                    }
            case let .delay(milliseconds):
                HStack(spacing: 14) {
                    Slider(
                        value: delayBinding(at: index, milliseconds: milliseconds),
                        in: 0.1...99.999,
                        step: 0.1
                    )
                    Text(String(format: "%.1f 秒", Double(milliseconds) / 1000))
                        .font(AppTypography.numeric)
                        .frame(width: 58, alignment: .trailing)
                }
            }

            if let validationMessage = validationMessage(for: step) {
                Text(validationMessage)
                    .font(AppTypography.supporting)
                    .foregroundStyle(Color.red)
            }
        }
        .padding(.horizontal, 68)
        .padding(.vertical, 13)
        .background(AppTheme.accent(for: colorScheme).opacity(0.035))
    }

    @ViewBuilder
    private var actionMenu: some View {
        workflowMenuHeader(
            showsAIPromptActions
                ? "选择 AI 操作"
                : showsSystemActions ? "选择系统动作" : "添加动作"
        )

        if showsAIPromptActions {
            ForEach(aiPromptActions) { action in
                workflowMenuRow(symbol: action.symbol, title: action.title, enabled: true) {
                    append(.action(action.id))
                }
            }
            workflowMenuRow(
                symbol: "arrow.left",
                title: "返回动作类型",
                enabled: true,
                showsInfo: false
            ) {
                showsAIPromptActions = false
            }
        } else if showsSystemActions {
            // URL actions remain available from the secondary action list;
            // the primary category rail now follows Options+'s seven-row
            // ordering exactly.
            workflowMenuRow(symbol: "link", title: "打开网址", enabled: true) {
                append(.url(""), configure: true)
            }
            ForEach(systemActions) { action in
                workflowMenuRow(symbol: action.symbol, title: action.title, enabled: true) {
                    append(.action(action.id))
                }
            }
            workflowMenuRow(
                symbol: "arrow.left",
                title: "返回动作类型",
                enabled: true,
                showsInfo: false
            ) {
                showsSystemActions = false
            }
        } else {
            workflowMenuRow(symbol: "sparkles", title: "AI Prompt Builder", enabled: true) {
                showsAIPromptActions = true
            }
            workflowMenuRow(symbol: "app.dashed", title: "应用", enabled: true) {
                chooseApplication(replacing: nil)
            }
            workflowMenuRow(symbol: "keyboard", title: "快捷键", enabled: true) {
                append(.keystroke(keyCode: 36, flags: 0, name: "Return"), configure: true)
            }
            workflowMenuRow(symbol: "text-cursor-input", title: "文本", enabled: true) {
                append(.text(""), configure: true)
            }
            workflowMenuRow(symbol: "bell-ring", title: "触觉反馈", enabled: false) {}
            workflowMenuRow(symbol: "gearshape", title: "系统", enabled: true) {
                showsSystemActions = true
            }
            Rectangle()
                .fill(AppTheme.separator(for: colorScheme))
                .frame(height: 1)
            workflowMenuRow(symbol: "clock-3", title: "延迟", enabled: true) {
                append(.delay(milliseconds: 1000), configure: true)
            }
        }
    }

    private func workflowMenuHeader(_ title: String) -> some View {
        Text(title)
            .font(.custom("AvenirNext-Bold", size: 16))
            .foregroundStyle(AppTheme.onAccent(for: colorScheme))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .frame(height: 48)
            .background(AppTheme.accent(for: colorScheme))
    }

    private func workflowMenuRow(
        symbol: String,
        title: String,
        enabled: Bool,
        showsInfo: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 15) {
                AppIcon(symbol: symbol, size: 20)
                    .frame(width: 24, height: 24)
                Text(title)
                    .font(.custom("AvenirNext-Bold", size: 16))
                Spacer()
                if showsInfo {
                    AppIcon(symbol: "info", size: 14)
                        .foregroundStyle(Color.secondary.opacity(enabled ? 0.62 : 0.42))
                }
            }
            .foregroundStyle(Color.primary.opacity(enabled ? 1 : 0.30))
            .padding(.horizontal, 20)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(QuietButtonStyle())
        .disabled(!enabled)
    }

    private var systemActions: [RemoteAction] {
        RemoteAction.catalog.filter {
            [.recommended, .system, .media].contains($0.category)
                && $0.id != "show-actions-ring"
        }
    }

    private var aiPromptActions: [RemoteAction] {
        RemoteAction.catalog.filter { $0.id.hasPrefix("smart-ai-") }
    }

    private var editorFooter: some View {
        HStack(alignment: .bottom, spacing: 12) {
            Button {
                guard let url = URL(string: "https://github.com/zhangtuansia/MiCoding#当前版本") else { return }
                NSWorkspace.shared.open(url)
            } label: {
                HStack(spacing: 8) {
                    AppIcon(symbol: "circle-question-mark", size: 18)
                    Text("需要帮助？")
                        .font(AppTypography.bodyMedium)
                }
            }
            .buttonStyle(QuietButtonStyle())

            Spacer()

            VStack(spacing: 10) {
                Button {
                    preview(effectiveTitle, steps)
                } label: {
                    HStack(spacing: 10) {
                        AppIcon(symbol: "play.fill", size: AppIconSize.control)
                        Text("试运行")
                    }
                }
                .buttonStyle(
                    SecondaryActionButtonStyle(width: SmartActionEditorLayoutMetrics.controlWidth)
                )
                .disabled(!stepsAreValid)

                Button(action: submit) {
                    HStack(spacing: 10) {
                        AppIcon(symbol: "checkmark", size: AppIconSize.control)
                        Text("保存")
                    }
                }
                .buttonStyle(
                    PrimaryActionButtonStyle(width: SmartActionEditorLayoutMetrics.controlWidth)
                )
                .disabled(!canSave)
            }
        }
        .padding(.leading, SmartActionEditorLayoutMetrics.footerLeadingInset)
        .padding(.trailing, SmartActionEditorLayoutMetrics.footerTrailingInset)
        .padding(.bottom, SmartActionEditorLayoutMetrics.footerBottomInset)
    }

    private var effectiveTitle: String {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "新建智能操作" : name
    }

    private var stepsAreValid: Bool {
        !steps.isEmpty
            && steps.allSatisfy(\.isValid)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !triggers.isEmpty
            && triggers.allSatisfy(\.isValid)
            && triggers.indices.allSatisfy { !triggerHasShortcutConflict(at: $0) }
            && stepsAreValid
    }

    private func triggerHasShortcutConflict(at index: Int) -> Bool {
        guard triggers.indices.contains(index),
              case let .shortcut(keyCode, flags, _) = triggers[index] else {
            return false
        }

        let conflictsWithSavedAction = reservedShortcutBindings.contains {
            $0.keyCode == keyCode && $0.flags == flags
        }
        guard !conflictsWithSavedAction else { return true }

        return triggers.indices.contains { candidateIndex in
            guard candidateIndex != index,
                  case let .shortcut(candidateKeyCode, candidateFlags, _) = triggers[candidateIndex]
            else {
                return false
            }
            return candidateKeyCode == keyCode && candidateFlags == flags
        }
    }

    private func sequenceBadge(number: Int, selected: Bool) -> some View {
        Text("\(number)")
            .font(AppTypography.numeric)
            .foregroundStyle(selected ? AppTheme.onAccent(for: colorScheme) : Color.primary.opacity(0.75))
            .frame(
                width: SmartActionEditorLayoutMetrics.sequenceBadgeSize,
                height: SmartActionEditorLayoutMetrics.sequenceBadgeSize
            )
            .background(
                selected
                    ? AppTheme.accent(for: colorScheme)
                    : AppTheme.canvas(for: colorScheme)
            )
            .clipShape(Circle())
            .overlay {
                Circle().stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
            }
    }

    private func stepNeedsConfiguration(_ step: SmartActionStep) -> Bool {
        switch step {
        case .action: false
        case .application, .applicationPath, .applicationControl, .keystroke, .text, .url, .delay: true
        }
    }

    private func validationMessage(for step: SmartActionStep) -> String? {
        guard !step.isValid else { return nil }
        return switch step {
        case .action:
            "此动作暂时没有可用的执行器。"
        case .application, .applicationPath, .applicationControl:
            "请选择一个有效的应用。"
        case .keystroke:
            "请录制要发送的快捷键。"
        case let .text(value):
            value.isEmpty ? "请输入要粘贴的文本。" : "文本不能超过 1000 个字符。"
        case .url:
            "请输入完整的 http:// 或 https:// 网址。"
        case .delay:
            "延迟必须介于 0.1 秒与 99.9 秒之间。"
        }
    }

    private func applicationConfiguration(
        bundleIdentifier: String,
        name: String,
        operation: ApplicationActionOperation,
        at index: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(AppTypography.bodyMedium)
                    Text(bundleIdentifier)
                        .font(AppTypography.supporting)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button("更换应用") { chooseApplication(replacing: index) }
                    .buttonStyle(InlineActionButtonStyle())
            }

            HStack(spacing: 14) {
                Text("应用动作")
                    .font(AppTypography.supportingMedium)
                Spacer()
                Picker(
                    "应用动作",
                    selection: applicationOperationBinding(
                        at: index,
                        bundleIdentifier: bundleIdentifier,
                        name: name,
                        fallback: operation
                    )
                ) {
                    ForEach(ApplicationActionOperation.allCases, id: \.self) { item in
                        Text(item.title).tag(item)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 142, alignment: .trailing)
            }
        }
    }

    private func append(_ step: SmartActionStep, configure: Bool = false) {
        steps.append(step)
        selectedStepIndex = configure ? steps.count - 1 : nil
        showsActionMenu = false
        showsAIPromptActions = false
        showsSystemActions = false
    }

    private func chooseApplication(replacing index: Int?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.message = "选择要由此 Smart Action 控制的应用"
        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier else { return }

        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        let existingOperation: ApplicationActionOperation = if let index,
                                                               steps.indices.contains(index),
                                                               case let .applicationControl(_, _, operation) = steps[index] {
            operation
        } else {
            .open
        }
        let step = SmartActionStep.applicationControl(
            bundleIdentifier: bundleIdentifier,
            name: name,
            operation: existingOperation
        )
        if let index, steps.indices.contains(index) {
            steps[index] = step
        } else {
            append(step)
        }
        showsActionMenu = false
    }

    private func chooseTriggerApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.message = "选择切换到前台时触发此 Smart Action 的应用"
        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier else { return }

        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        guard !triggers.contains(where: { trigger in
            guard case let .application(existingBundleIdentifier, _) = trigger else {
                return false
            }
            return existingBundleIdentifier == bundleIdentifier
        }) else {
            showsTriggerMenu = false
            return
        }

        triggers.append(.application(bundleIdentifier: bundleIdentifier, name: name))
        selectedTriggerIndex = nil
        showsTriggerMenu = false
    }

    private func applicationOperationBinding(
        at index: Int,
        bundleIdentifier: String,
        name: String,
        fallback: ApplicationActionOperation
    ) -> Binding<ApplicationActionOperation> {
        Binding(
            get: {
                guard steps.indices.contains(index) else { return fallback }
                if case let .applicationControl(_, _, operation) = steps[index] {
                    return operation
                }
                return .open
            },
            set: { operation in
                steps[index] = .applicationControl(
                    bundleIdentifier: bundleIdentifier,
                    name: name,
                    operation: operation
                )
            }
        )
    }

    private func textBinding(at index: Int, value: String) -> Binding<String> {
        Binding(
            get: {
                guard steps.indices.contains(index), case let .text(current) = steps[index] else {
                    return value
                }
                return current
            },
            set: { steps[index] = .text(String($0.prefix(1000))) }
        )
    }

    private func urlBinding(at index: Int, value: String) -> Binding<String> {
        Binding(
            get: {
                guard steps.indices.contains(index), case let .url(current) = steps[index] else {
                    return value
                }
                return current
            },
            set: { steps[index] = .url($0) }
        )
    }

    private func delayBinding(at index: Int, milliseconds: Int) -> Binding<Double> {
        Binding(
            get: {
                guard steps.indices.contains(index), case let .delay(current) = steps[index] else {
                    return Double(milliseconds) / 1000
                }
                return Double(current) / 1000
            },
            set: { steps[index] = .delay(milliseconds: Int(($0 * 1000).rounded())) }
        )
    }

    private func submit() {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSave, let firstStep = steps.first else { return }
        save(
            SmartAction(
                id: editing?.id ?? UUID().uuidString,
                actionID: editing?.actionID ?? "custom-smart-\(UUID().uuidString)",
                title: name,
                subtitle: SmartAction.workflowSubtitle(for: steps),
                symbol: firstStep.symbol,
                tint: firstStep.tint,
                stepCount: SmartAction.workflowStepCount(for: steps),
                steps: steps,
                triggers: triggers,
                isEnabled: editing?.isEnabled ?? true
            )
        )
    }
}

private extension SmartActionTrigger {
    var symbol: String {
        switch self {
        case .application: "app.dashed"
        case .device: "av.remote"
        case .actionsRing: "circle-dot"
        case .shortcut: "keyboard"
        }
    }

    var title: String {
        switch self {
        case let .application(_, name): name
        case .device: "Xiaomi Remote 2 Pro"
        case .actionsRing: "Actions Ring"
        case .shortcut: "全局快捷键"
        }
    }

    var subtitle: String {
        switch self {
        case let .application(bundleIdentifier, _): "切换至前台时触发 · \(bundleIdentifier)"
        case .device: "保存后可分配至任意遥控器按键"
        case .actionsRing: "保存后可在 Actions Ring 中分配"
        case let .shortcut(_, _, name): name
        }
    }

    var isShortcut: Bool {
        guard case .shortcut = self else { return false }
        return true
    }
}

private extension View {
    func workflowPanel(colorScheme: ColorScheme) -> some View {
        background(AppTheme.surface(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
            }
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.18 : 0.10),
                radius: 10,
                x: 4,
                y: 4
            )
    }
}

private struct SmartActionStepDropDelegate: DropDelegate {
    let destinationIndex: Int
    @Binding var steps: [SmartActionStep]
    @Binding var draggingIndex: Int?
    @Binding var selectedIndex: Int?

    func dropEntered(info: DropInfo) {
        guard let sourceIndex = draggingIndex,
              sourceIndex != destinationIndex,
              steps.indices.contains(sourceIndex),
              steps.indices.contains(destinationIndex) else { return }

        withAnimation(.easeOut(duration: 0.16)) {
            steps.move(
                fromOffsets: IndexSet(integer: sourceIndex),
                toOffset: destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex
            )
            draggingIndex = destinationIndex
            selectedIndex = destinationIndex
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingIndex = nil
        return true
    }
}

struct ShortcutRecorderField: NSViewRepresentable {
    let displayName: String
    var showsPlaceholder = false
    let onRecord: (UInt16, UInt64, String) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.displayName = displayName
        view.showsPlaceholder = showsPlaceholder
        view.onRecord = onRecord
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.displayName = displayName
        nsView.showsPlaceholder = showsPlaceholder
        nsView.onRecord = onRecord
        nsView.needsDisplay = true
    }
}

final class ShortcutRecorderNSView: NSView {
    var displayName = "Return"
    var showsPlaceholder = false
    var onRecord: ((UInt16, UInt64, String) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    override func resignFirstResponder() -> Bool {
        needsDisplay = true
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        record(event)
    }

    /// AppKit normally sends Command-based combinations through the menu's
    /// key-equivalent path before the first responder receives `keyDown`.
    /// Intercept that path only while recording so ⌘C, ⌘⇧S, and similar
    /// shortcuts are captured instead of executing Edit menu commands.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self, event.type == .keyDown else {
            return super.performKeyEquivalent(with: event)
        }
        record(event)
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4)
        (window?.firstResponder === self
            ? NSColor.systemPurple.withAlphaComponent(0.12)
            : NSColor.controlBackgroundColor).setFill()
        path.fill()
        (window?.firstResponder === self
            ? NSColor.systemPurple
            : NSColor.separatorColor).setStroke()
        path.lineWidth = 1
        path.stroke()

        let text = window?.firstResponder === self ? "请按下快捷键…" : displayName
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: showsPlaceholder && window?.firstResponder !== self
                ? NSColor.placeholderTextColor
                : NSColor.labelColor
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(
            at: NSPoint(x: 12, y: (bounds.height - size.height) / 2),
            withAttributes: attributes
        )
    }

    private func record(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let name = Self.displayName(
            keyCode: event.keyCode,
            characters: event.charactersIgnoringModifiers,
            modifiers: modifiers
        )
        onRecord?(event.keyCode, UInt64(modifiers.rawValue), name)
        window?.makeFirstResponder(nil)
        needsDisplay = true
    }

    static func displayName(
        keyCode: UInt16,
        characters: String?,
        modifiers: NSEvent.ModifierFlags
    ) -> String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        if modifiers.contains(.function) { result += "fn " }

        let keyName: String = switch keyCode {
        case 36: "Return"
        case 48: "Tab"
        case 49: "Space"
        case 51: "Delete"
        case 53: "Esc"
        case 64: "F17"
        case 79: "F18"
        case 80: "F19"
        case 90: "F20"
        case 96: "F5"
        case 97: "F6"
        case 98: "F7"
        case 99: "F3"
        case 100: "F8"
        case 103: "F11"
        case 105: "F13"
        case 106: "F16"
        case 107: "F14"
        case 109: "F10"
        case 111: "F12"
        case 113: "F15"
        case 114: "Help"
        case 115: "Home"
        case 116: "Page Up"
        case 117: "Forward Delete"
        case 118: "F4"
        case 119: "End"
        case 120: "F2"
        case 121: "Page Down"
        case 122: "F1"
        case 123: "←"
        case 124: "→"
        case 125: "↓"
        case 126: "↑"
        default: characters?.uppercased() ?? "Key \(keyCode)"
        }
        return result + keyName
    }
}

private struct EmptySmartActionsView: View {
    var body: some View {
        VStack(spacing: 0) {
            EmptySmartActionsIllustration()
                .frame(width: 600, height: 300)
                .padding(.top, 84)
                // Keep the artwork's ground line independent from the copy.
                // Once the shared guide/filter stack is aligned, its visible
                // baseline still needs an 8 pt optical lift to match Options+.
                .offset(y: AutomationLibraryLayoutMetrics.emptyIllustrationYOffset)

            Text("点击“创建”以添加您的首个 Smart Actions，或者从模板中添加。")
                .font(.custom("AvenirNext-Regular", size: 16))
                .multilineTextAlignment(.center)
                .padding(.top, AutomationLibraryLayoutMetrics.emptyCopyTopInset)
        }
        .frame(width: 840)
        .frame(minHeight: 500, alignment: .top)
        .offset(x: -45)
    }
}

private struct EmptySmartActionsIllustration: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(AppTheme.accent(for: colorScheme).opacity(0.045))
                .frame(
                    width: AutomationLibraryLayoutMetrics.emptyIllustrationDiamondSide,
                    height: AutomationLibraryLayoutMetrics.emptyIllustrationDiamondSide
                )
                .rotationEffect(.degrees(45))
                .offset(y: -4.5)

            decorativeMark(color: .red, width: 19)
                .offset(x: -190, y: -94)
            decorativeMark(color: AppTheme.mint, width: 17)
                .offset(x: 177, y: -76)
            decorativeMark(color: .blue, width: 18)
                .offset(x: 146, y: 60)

            Circle()
                .fill(.orange.opacity(0.78))
                .frame(width: 8, height: 8)
                .offset(x: -152, y: -121)
            Circle()
                .fill(AppTheme.mint.opacity(0.72))
                .frame(width: 8, height: 8)
                .offset(x: 136, y: -114)

            EmptyActionTriangle()
                .fill(AppTheme.mint.opacity(colorScheme == .dark ? 0.34 : 0.18))
                .frame(width: 19, height: 17)
                .rotationEffect(.degrees(-18))
                .offset(x: -193, y: 53)

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.72 : 0.82))
                .frame(
                    width: AutomationLibraryLayoutMetrics.emptyIllustrationKeyboardSize.width,
                    height: AutomationLibraryLayoutMetrics.emptyIllustrationKeyboardSize.height
                )
                .overlay {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(17), spacing: 5), count: 4), spacing: 5) {
                        ForEach(0..<20, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(Color.white.opacity(0.72))
                                .frame(width: 17, height: 15)
                        }
                    }
                }
                .rotationEffect(.degrees(-26))
                .shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.20 : 0.13),
                    radius: 5,
                    x: 4,
                    y: 6
                )
                .offset(
                    x: AutomationLibraryLayoutMetrics.emptyIllustrationKeyboardOffset.width,
                    y: AutomationLibraryLayoutMetrics.emptyIllustrationKeyboardOffset.height
                )

            EmptyActionMouse()
                .frame(
                    width: AutomationLibraryLayoutMetrics.emptyIllustrationMouseSize.width,
                    height: AutomationLibraryLayoutMetrics.emptyIllustrationMouseSize.height
                )
                .rotationEffect(.degrees(15))
                .offset(
                    x: AutomationLibraryLayoutMetrics.emptyIllustrationMouseOffset.width,
                    y: AutomationLibraryLayoutMetrics.emptyIllustrationMouseOffset.height
                )

            EmptyActionPlant()
                .frame(width: 54, height: 80)
                .scaleEffect(
                    x: AutomationLibraryLayoutMetrics.emptyIllustrationPlantScale.width,
                    y: AutomationLibraryLayoutMetrics.emptyIllustrationPlantScale.height
                )
                .offset(
                    x: AutomationLibraryLayoutMetrics.emptyIllustrationPlantOffset.width,
                    y: AutomationLibraryLayoutMetrics.emptyIllustrationPlantOffset.height
                )

            ZStack(alignment: .bottom) {
                EmptyActionBoxFlap()
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color(white: 0.26), Color(white: 0.18)]
                                : [
                                    Color(red: 0.86, green: 0.88, blue: 0.95),
                                    Color(red: 0.96, green: 0.97, blue: 0.995)
                                ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay {
                        EmptyActionBoxFlap()
                            .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
                    }
                    .frame(
                        width: AutomationLibraryLayoutMetrics.emptyIllustrationBoxFlapSize.width,
                        height: AutomationLibraryLayoutMetrics.emptyIllustrationBoxFlapSize.height
                    )

                EmptyActionBoxSide()
                    .fill(
                        LinearGradient(
                            colors: [
                                colorScheme == .dark
                                    ? Color(white: 0.30)
                                    : Color(red: 0.80, green: 0.82, blue: 0.90),
                                colorScheme == .dark
                                    ? Color(white: 0.20)
                                    : Color(red: 0.70, green: 0.73, blue: 0.84)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(
                        width: AutomationLibraryLayoutMetrics.emptyIllustrationBoxSideSize.width,
                        height: AutomationLibraryLayoutMetrics.emptyIllustrationBoxSideSize.height
                    )
                    .offset(
                        x: AutomationLibraryLayoutMetrics.emptyIllustrationBoxSideOffset.width,
                        y: AutomationLibraryLayoutMetrics.emptyIllustrationBoxSideOffset.height
                    )

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color(white: 0.22), Color(white: 0.16)]
                                : [
                                    Color(red: 0.96, green: 0.97, blue: 0.995),
                                    Color(red: 0.92, green: 0.94, blue: 0.98)
                                ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(
                        width: AutomationLibraryLayoutMetrics.emptyIllustrationBoxFrontSize.width,
                        height: AutomationLibraryLayoutMetrics.emptyIllustrationBoxFrontSize.height
                    )
                    .overlay {
                        Text("MiCoding")
                            .font(.custom("AvenirNext-DemiBold", size: 10.5))
                            .tracking(-0.35)
                            .foregroundStyle(Color.primary.opacity(colorScheme == .dark ? 0.26 : 0.18))
                    }
                    .offset(y: AutomationLibraryLayoutMetrics.emptyIllustrationBoxFrontYOffset)
            }
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.15 : 0.05),
                radius: 8,
                x: 6,
                y: 5
            )
            .offset(
                x: AutomationLibraryLayoutMetrics.emptyIllustrationBoxXOffset,
                y: 92
            )

            Circle()
                .fill(AppTheme.accent(for: colorScheme))
                .frame(width: 54, height: 54)
                .overlay {
                    AppIcon(symbol: "plus", size: 27)
                        .foregroundStyle(AppTheme.onAccent(for: colorScheme))
                }
                .offset(
                    x: AutomationLibraryLayoutMetrics.emptyIllustrationPlusXOffset,
                    y: AutomationLibraryLayoutMetrics.emptyIllustrationPlusYOffset
                )

            Circle()
                .fill(AppTheme.accent(for: colorScheme).opacity(colorScheme == .dark ? 0.18 : 0.13))
                .frame(
                    width: AutomationLibraryLayoutMetrics.emptyIllustrationOrbSize,
                    height: AutomationLibraryLayoutMetrics.emptyIllustrationOrbSize
                )
                .overlay {
                    Circle()
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.22))
                        .frame(width: 12, height: 12)
                        .offset(x: -5, y: -5)
                }
                .offset(
                    x: AutomationLibraryLayoutMetrics.emptyIllustrationOrbOffset.width,
                    y: AutomationLibraryLayoutMetrics.emptyIllustrationOrbOffset.height
                )

            Capsule()
                .fill(Color.primary.opacity(0.15))
                .frame(width: 390, height: 3)
                .offset(y: 153)
        }
        .accessibilityHidden(true)
    }

    private func decorativeMark(color: Color, width: CGFloat) -> some View {
        Capsule()
            .fill(color.opacity(0.72))
            .frame(width: width, height: 2)
    }
}

private struct EmptyActionPlant: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .bottom) {
            EmptyActionLeaf()
                .fill(leafColor.opacity(0.82))
                .frame(width: 17, height: 48)
                .rotationEffect(.degrees(-38), anchor: .bottom)
                .offset(x: -10, y: -18)

            EmptyActionLeaf()
                .fill(leafColor)
                .frame(width: 18, height: 55)
                .rotationEffect(.degrees(7), anchor: .bottom)
                .offset(x: 1, y: -18)

            EmptyActionLeaf()
                .fill(leafColor.opacity(0.72))
                .frame(width: 16, height: 43)
                .rotationEffect(.degrees(43), anchor: .bottom)
                .offset(x: 11, y: -18)

            EmptyActionPlantPot()
                .fill(
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [Color(red: 0.48, green: 0.50, blue: 0.73), Color(red: 0.29, green: 0.31, blue: 0.52)]
                            : [Color(red: 0.66, green: 0.70, blue: 0.91), Color(red: 0.43, green: 0.47, blue: 0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 34, height: 28)
        }
        .accessibilityHidden(true)
    }

    private var leafColor: Color {
        colorScheme == .dark
            ? Color(red: 0.18, green: 0.76, blue: 0.63)
            : Color(red: 0.22, green: 0.82, blue: 0.68)
    }
}

private struct EmptyActionLeaf: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addCurve(
                to: CGPoint(x: rect.midX, y: rect.minY),
                control1: CGPoint(x: rect.minX - 1, y: rect.height * 0.62),
                control2: CGPoint(x: rect.minX + 1, y: rect.height * 0.18)
            )
            path.addCurve(
                to: CGPoint(x: rect.midX, y: rect.maxY),
                control1: CGPoint(x: rect.maxX - 1, y: rect.height * 0.18),
                control2: CGPoint(x: rect.maxX + 1, y: rect.height * 0.62)
            )
            path.closeSubpath()
        }
    }
}

private struct EmptyActionPlantPot: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - 5, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + 5, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct EmptyActionTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

/// A lightweight vector counterpart to the mouse in the Options+ empty-state
/// artwork.  Keeping this code-native lets the illustration follow dark mode
/// without bundling a screenshot or a vendor-owned raster asset.
private struct EmptyActionMouse: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: size.width * 0.46, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color(white: 0.66), Color(white: 0.43)]
                                : [Color(white: 0.91), Color(white: 0.67)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: size.width * 0.46, style: .continuous)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.22 : 0.62), lineWidth: 1)
                    }

                Path { path in
                    path.move(to: CGPoint(x: size.width * 0.5, y: 4))
                    path.addLine(to: CGPoint(x: size.width * 0.5, y: size.height * 0.39))
                }
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.24 : 0.72), lineWidth: 1)

                Capsule()
                    .fill(Color.black.opacity(colorScheme == .dark ? 0.68 : 0.58))
                    .frame(width: 8, height: 20)
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(0.32), lineWidth: 0.8)
                    }
                    .padding(.top, 13)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.18 : 0.12), radius: 4, x: 2, y: 4)
        }
        .accessibilityHidden(true)
    }
}

private struct EmptyActionBoxFlap: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.width * 0.78, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.width * 0.22, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct EmptyActionBoxSide: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + 8))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct EmptyAutomationSearchView: View {
    let clear: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label {
                Text("没有匹配的组合动作")
            } icon: {
                AppIcon(symbol: "magnifyingglass", size: 34)
            }
        } description: {
            Text("换一个关键词，或清除当前分类。")
        } actions: {
            Button("清除筛选", action: clear)
                .buttonStyle(SecondaryActionButtonStyle())
        }
        .frame(maxWidth: .infinity, minHeight: 310)
        .frame(width: 840)
    }
}

private struct AutomationPrivacyNote: View {
    var body: some View {
        HStack(spacing: 9) {
            AppIcon(symbol: "checkmark.shield.fill", size: AppIconSize.control)
                .foregroundStyle(.secondary)
            Text("组合动作和运行记录只保存在这台 Mac。")
                .font(AppTypography.supporting)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 3)
    }
}

enum SettingsLayoutMetrics {
    static let referenceWindowWidth: CGFloat = 1_180
    static let referenceNavigationWidth: CGFloat = 403
    static let contentLeadingPadding: CGFloat = 59
    // Measured from matched 2× content captures. Options+ paints the right
    // page-title ink at y=34.5 pt and the left title at y=38 pt; these insets
    // compensate for Avenir Next's different ascent without changing sizes.
    static let contentTopPadding: CGFloat = 32.5
    static let navigationTopPadding: CGFloat = 25
    static let navigationListTopPadding: CGFloat = 152.5
    static let navigationBackOpticalXOffset: CGFloat = -7.5
    static let navigationTitleOpticalYOffset: CGFloat = 3.5
    static let textLinkOpticalXScale: CGFloat = 1.075
    static let textLinkOpticalYOffset: CGFloat = -4
    static let pageTitleOpticalWidthScale: CGFloat = 1
    static let pageTitleOpticalHeightScale: CGFloat = 1
    static let pageTitleOpticalYOffset: CGFloat = -2
    static let servicePageTitleOpticalYOffset: CGFloat = 0
    static let sectionTitleOpticalWidthScale: CGFloat = 1.008
    static let sectionTitleOpticalHeightScale: CGFloat = 0.97
    static let themeSectionTitleOpticalYOffset: CGFloat = 1

    static func navigationWidth(for windowWidth: CGFloat) -> CGFloat {
        windowWidth * (referenceNavigationWidth / referenceWindowWidth)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var selection: SettingsSection

    init(initialSelection: SettingsSection = .general) {
        _selection = State(initialValue: initialSelection)
    }

    var body: some View {
        GeometryReader { proxy in
            // Options+ reserves a measured 403 pt navigation column in the
            // 1,180 pt window. Keeping the same ratio preserves that split
            // when the window grows.
            let navigationWidth = SettingsLayoutMetrics.navigationWidth(for: proxy.size.width)
            HStack(spacing: 0) {
                settingsNavigation
                    .frame(width: navigationWidth)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                    .background(AppTheme.canvas(for: colorScheme))

                ScrollView {
                    settingsContent
                        .frame(maxWidth: 590, alignment: .leading)
                        .padding(.leading, SettingsLayoutMetrics.contentLeadingPadding)
                        .padding(.top, SettingsLayoutMetrics.contentTopPadding)
                        .padding(.bottom, 48)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)
                .frame(width: proxy.size.width - navigationWidth)
                .background(AppTheme.canvas(for: colorScheme))
            }
        }
        .background(AppTheme.canvas(for: colorScheme))
    }

    private var settingsNavigation: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    store.leaveSettings()
                } label: {
                    AppIcon(symbol: "arrow.left", size: 22)
                        .frame(width: 30, height: 40)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(QuietButtonStyle())
                .keyboardShortcut(.cancelAction)
                .help("返回")
                .accessibilityLabel("返回主页")
                .offset(x: SettingsLayoutMetrics.navigationBackOpticalXOffset)

                Text("应用程序设置")
                    .font(AppTypography.settingsTitle)
                    .tracking(-0.45)
                    .lineLimit(2)
                    // The expanded 46 × 48 back-button hit target must not
                    // move the reference-aligned title that follows it.
                    .offset(
                        x: -16,
                        y: SettingsLayoutMetrics.navigationTitleOpticalYOffset
                    )
            }
            .padding(.leading, 21)
            .padding(.top, SettingsLayoutMetrics.navigationTopPadding)
            .frame(minWidth: 350, alignment: .leading)
            .offset(y: -0.5)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(SettingsSection.allCases) { section in
                    SettingsSidebarItem(
                        section: section,
                        selected: selection == section
                    ) {
                        selection = section
                    }
                }
            }
            .padding(.top, SettingsLayoutMetrics.navigationListTopPadding)
            .padding(.vertical, 20)
            .frame(width: 300, alignment: .leading)

            Spacer()
        }
    }

    @ViewBuilder
    private var settingsContent: some View {
        switch selection {
        case .general:
            GeneralSettingsContent(appVersion: appVersion)

        case .services:
            ServiceSettingsContent(appVersion: appVersion)

        case .notifications:
            NotificationSettingsContent()

        case .privacy:
            PrivacySettingsContent()
        }
    }

    private var appVersion: String {
        guard Bundle.main.bundleIdentifier == "io.xiaomiremote.studio" else { return "0.2.0" }
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.0"
    }

}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case services
    case notifications
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "通用"
        case .services: "MiCoding 服务"
        case .notifications: "通知"
        case .privacy: "隐私与数据"
        }
    }

}

private extension View {
    /// Keep the layout box intact while applying only the measured ink-bound
    /// correction for each heading tier. Page titles now match at natural
    /// size; compact section titles still need a small vertical correction.
    func settingsPageTitleOpticalBounds() -> some View {
        scaleEffect(
            x: SettingsLayoutMetrics.pageTitleOpticalWidthScale,
            y: SettingsLayoutMetrics.pageTitleOpticalHeightScale,
            anchor: .topLeading
        )
    }

    func settingsSectionTitleOpticalBounds() -> some View {
        scaleEffect(
            x: SettingsLayoutMetrics.sectionTitleOpticalWidthScale,
            y: SettingsLayoutMetrics.sectionTitleOpticalHeightScale,
            anchor: .topLeading
        )
    }
}

private struct GeneralSettingsContent: View {
    let appVersion: String

    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("常规设置")
                .font(AppTypography.pageTitle)
                .settingsPageTitleOpticalBounds()
                .offset(y: SettingsLayoutMetrics.pageTitleOpticalYOffset)

            VStack(alignment: .leading, spacing: 0) {
                Text("MiCoding 版本 \(appVersion)")
                    .font(AppTypography.title)
                    .settingsSectionTitleOpticalBounds()
                    .offset(y: 2)

                HStack(spacing: 12) {
                    Text(store.softwareUpdateStatus.message)
                        .font(AppTypography.body)
                        .tracking(0.9)
                        .foregroundStyle(.secondary)
                        .scaleEffect(x: 1, y: 0.895, anchor: .top)
                        .offset(x: 0.5)

                    Button(
                        store.softwareUpdateStatus.releaseURL == nil
                            ? "查看发布说明"
                            : "下载更新"
                    ) {
                        store.openUpdatePage()
                    }
                        .buttonStyle(InlineActionButtonStyle())
                        .offset(y: -2.5)
                }
                .padding(.top, 11.5)
                .offset(y: 0.5)

                Button("检查更新") { store.checkForUpdates() }
                    .buttonStyle(SettingsTextLinkStyle())
                    .disabled(store.softwareUpdateStatus == .checking)
                    .opacity(store.softwareUpdateStatus == .checking ? 0.42 : 1)
                    .padding(.top, 3)
                    .offset(x: -1, y: -2)
            }
            .padding(.top, 30)
            .offset(y: -5)

            HStack {
                Text("自动安装软件更新")
                    .font(AppTypography.title)
                    .settingsSectionTitleOpticalBounds()
                Spacer()
                CompactSettingsToggle(isOn: Binding(
                    get: { store.automaticUpdatesEnabled },
                    set: { store.setAutomaticUpdates($0) }
                ), accessibilityLabel: "自动安装软件更新")
            }
            .frame(width: 555)
            .padding(.top, 26)
            .offset(y: -1.5)

            VStack(alignment: .leading, spacing: 0) {
                Text("语言")
                    .font(AppTypography.title)
                    .settingsSectionTitleOpticalBounds()
                    .offset(y: -1)

                Menu {
                    Button {} label: {
                        Label("使用系统语言", systemImage: "checkmark")
                    }
                    .disabled(true)

                    Divider()

                    Button("打开语言与地区设置…") {
                        store.openLanguageSettings()
                    }
                } label: {
                    Color.clear
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 235, height: 48)
                .overlay(alignment: .leading) {
                    Text("使用系统语言")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(Color.primary)
                        .padding(.leading, 22)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .trailing) {
                    AppIcon(symbol: "chevron.down", size: AppIconSize.indicator)
                        .foregroundStyle(Color.primary)
                        .padding(.trailing, 18)
                        .allowsHitTesting(false)
                }
                .background(AppTheme.primarySurface(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(AppTheme.controlBorder(for: colorScheme), lineWidth: 1)
                }
                .offset(x: -20.5, y: 0.5)
                .padding(.top, 11)
                .help("使用 macOS 系统语言；当前显示为简体中文")
                .accessibilityLabel("使用系统语言")
            }
            .padding(.top, 42)
            .offset(y: -2.5)

            VStack(alignment: .leading, spacing: 0) {
                Text("颜色主题")
                    .font(AppTypography.title)
                    // Unlike the compact row headings, Options+ gives this
                    // 22.875 pt line box its full painted height. Keeping the
                    // regular vertical scale matches the taller reference ink
                    // bounds without disturbing the card geometry below it.
                    .scaleEffect(
                        x: SettingsLayoutMetrics.sectionTitleOpticalWidthScale,
                        y: 1,
                        anchor: .topLeading
                    )
                    .tracking(0.2)
                    .offset(y: SettingsLayoutMetrics.themeSectionTitleOpticalYOffset)

                HStack(spacing: 30) {
                    ForEach(AppAppearanceMode.allCases) { mode in
                        AppearanceThemeCard(
                            mode: mode,
                            selected: store.appearanceMode == mode
                        ) {
                            store.setAppearanceMode(mode)
                        }
                    }
                }
                .padding(.top, 14.25)
            }
            .padding(.top, 47)
        }
    }

}

private struct FeedbackSettingsContent: View {
    let appVersion: String

    @EnvironmentObject private var store: AppStore
    @State private var bluetoothIssues: Set<String> = []

    private let issueOptions = [
        "蓝牙配对困难",
        "设备频繁断开连接",
        "使用蓝牙时有延迟"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("反馈与支持")
                .font(AppTypography.pageTitle)
                .settingsPageTitleOpticalBounds()
                .offset(y: SettingsLayoutMetrics.pageTitleOpticalYOffset)

            SettingsEditorialSection(
                title: "一般反馈",
                description: "您到目前为止对 MiCoding 的体验如何？欢迎在下方分享您的想法。您的反馈有助于我们改进 MiCoding。",
                actionTitle: "分享一般反馈",
                action: { openGitHub(path: "/issues/new?labels=feedback") }
            )
            .padding(.top, 28.5)

            SettingsEditorialSection(
                title: "为您的使用体验评分",
                description: "请花些时间评价一下您对本软件的使用体验。",
                actionTitle: "立即评分",
                action: { openGitHub(path: "") }
            )
            .padding(.top, 26.5)

            SettingsEditorialSection(
                title: "故障排除和支持",
                description: "报告问题或请求支持。",
                actionTitle: "报告问题/请求支持",
                action: { openGitHub(path: "/issues/new?labels=support") }
            )
            .padding(.top, 26.5)

            VStack(alignment: .leading, spacing: 0) {
                Text("蓝牙连接问题")
                    .font(AppTypography.title)
                    .settingsSectionTitleOpticalBounds()
                    .offset(y: -4)

                Text("如果遥控器遇到蓝牙连接问题，请勾选症状并导出报告。报告只包含 MiCoding 版本、权限状态、连接状态和本次运行日志。")
                    .font(AppTypography.body)
                    .foregroundStyle(Color.primary.opacity(0.72))
                    .lineSpacing(1)
                    .padding(.top, 12)
                    .offset(y: 5.5)

                Button("查看连接说明") { openGitHub(path: "#运行") }
                    .buttonStyle(SettingsTextLinkStyle())
                    .padding(.top, 8)
                    .offset(y: -5)

                VStack(alignment: .leading, spacing: 13) {
                    ForEach(Array(issueOptions.enumerated()), id: \.element) { index, issue in
                        Button {
                            if bluetoothIssues.contains(issue) {
                                bluetoothIssues.remove(issue)
                            } else {
                                bluetoothIssues.insert(issue)
                            }
                        } label: {
                            HStack(spacing: 14) {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(bluetoothIssues.contains(issue) ? AppTheme.purple : Color.primary.opacity(0.10))
                                    .frame(width: 20, height: 20)
                                    .overlay {
                                        if bluetoothIssues.contains(issue) {
                                            AppIcon(symbol: "checkmark", size: 12)
                                                .foregroundStyle(.white)
                                        }
                                    }
                                Text(issue)
                                    .font(AppTypography.bodyMedium)
                            }
                            .foregroundStyle(Color.primary)
                        }
                        .buttonStyle(QuietButtonStyle())
                        .offset(y: index == 0 ? 2 : 0)
                    }
                }
                .padding(.top, 16)
                .offset(x: 7.5, y: -3)

                Button("导出蓝牙报告") { exportBluetoothReport() }
                    .buttonStyle(SettingsTextLinkStyle())
                    .disabled(bluetoothIssues.isEmpty)
                    .opacity(bluetoothIssues.isEmpty ? 0.35 : 1)
                    .padding(.top, 28)
                    .offset(x: 8, y: -6)
            }
            .padding(.top, 30)
        }
    }

    private func openGitHub(path: String) {
        guard let url = URL(string: "https://github.com/zhangtuansia/MiCoding\(path)") else { return }
        NSWorkspace.shared.open(url)
    }

    private func exportBluetoothReport() {
        let report = """
        MiCoding Bluetooth Diagnostic Report
        Version: \(appVersion)
        Generated: \(Date().formatted(date: .numeric, time: .standard))
        Symptoms: \(bluetoothIssues.sorted().joined(separator: ", "))
        Device: \(store.deviceConnectionDetail)
        Input Monitoring: \(store.permissions.inputMonitoringGranted ? "granted" : "not granted")
        Accessibility: \(store.permissions.accessibilityGranted ? "granted" : "not granted")
        Backend: \(store.backendLog)
        """

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "MiCoding-Bluetooth-Diagnostic.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? Data(report.utf8).write(to: url, options: .atomic)
    }
}

private struct SettingsEditorialSection: View {
    let title: String
    let description: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(AppTypography.title)
                .settingsSectionTitleOpticalBounds()
                .offset(y: -3.5)
            Text(description)
                .font(AppTypography.body)
                .foregroundStyle(Color.primary.opacity(0.72))
                .lineSpacing(0)
                .padding(.top, 8)
            Button(actionTitle, action: action)
                .buttonStyle(SettingsTextLinkStyle())
                .padding(.top, 8)
                .offset(y: -3)
        }
    }
}

private struct ServiceSettingsContent: View {
    let appVersion: String

    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("MiCoding 服务")
                .font(AppTypography.pageTitle)
                .settingsPageTitleOpticalBounds()
                .offset(y: SettingsLayoutMetrics.servicePageTitleOpticalYOffset)

            Text("MiCoding 输入服务版本 \(appVersion)")
                .font(AppTypography.title)
                .settingsSectionTitleOpticalBounds()
                .padding(.top, 28)

            HStack {
                Text("在后台运行 MiCoding 输入服务")
                    .font(AppTypography.title)
                    .settingsSectionTitleOpticalBounds()
                Spacer()
                CompactSettingsToggle(
                    isOn: Binding(
                        get: { store.inputServiceEnabled },
                        set: { store.setInputServiceEnabled($0) }
                    ),
                    accessibilityLabel: "在后台运行 MiCoding 输入服务"
                )
            }
            .frame(width: 555)
            .padding(.top, 30)

            Text("MiCoding 输入服务对于确保按键监听、应用 Profile 和 Smart Actions 在后台顺畅运行至关重要。它还会在前台应用切换后继续使用正确的按键配置。如果禁用，后台监听将停止运行，按键和自动化动作可能无法正常工作。")
                .font(AppTypography.body)
                .foregroundStyle(Color.primary.opacity(0.72))
                .lineSpacing(1)
                .frame(width: 511, alignment: .leading)
                .padding(.top, 12.5)

            HStack(spacing: 4) {
                Text("如需了解更多信息，请访问")
                    .font(AppTypography.body)
                    .foregroundStyle(Color.primary.opacity(0.72))
                Button("MiCoding 输入服务支持页面") { openInputServiceSupport() }
                    .buttonStyle(SettingsTextLinkStyle())
            }
            .padding(.top, 5.5)

            VStack(alignment: .leading, spacing: 0) {
                Text("重新启动 MiCoding 输入服务")
                    .font(AppTypography.title)
                    .settingsSectionTitleOpticalBounds()
                Text("如果设备按键或应用专属配置遇到问题，请重新启动输入服务。")
                    .font(AppTypography.body)
                    .foregroundStyle(Color.primary.opacity(0.72))
                    .padding(.top, 10)
                    .offset(y: -3.5)
                Button("重新启动输入服务") { store.restartBackend(announce: true) }
                    .buttonStyle(SettingsTextLinkStyle())
                    .padding(.top, 4.5)
                    .offset(y: 2)
                    .disabled(!store.inputServiceEnabled)
                    .opacity(store.inputServiceEnabled ? 1 : 0.35)
            }
            .padding(.top, 28)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("屏幕叠加")
                        .font(AppTypography.title)
                        .settingsSectionTitleOpticalBounds()
                    Spacer()
                    CompactSettingsToggle(
                        isOn: Binding(
                            get: { store.showActionNotifications },
                            set: { store.setActionNotifications($0) }
                        ),
                        accessibilityLabel: "屏幕叠加"
                    )
                }
                .frame(width: 555)
                Text("禁用以在执行、分配或修改动作时隐藏屏幕叠加。")
                    .font(AppTypography.body)
                    .foregroundStyle(Color.primary.opacity(0.72))
                    .padding(.top, 12)
            }
            .padding(.top, 39)
        }
        .offset(y: -2)
    }

    private func openInputServiceSupport() {
        guard let url = URL(string: "https://github.com/zhangtuansia/MiCoding#本地数据与权限") else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct NotificationSettingsContent: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("通知")
                .font(AppTypography.pageTitle)
                .settingsPageTitleOpticalBounds()
                .offset(y: SettingsLayoutMetrics.pageTitleOpticalYOffset)

            Text("通用")
                .font(AppTypography.title)
                .settingsSectionTitleOpticalBounds()
                .tracking(0.5)
                .padding(.top, 30)
                .offset(y: -3.5)

            NotificationSwitchRow(
                title: "应用程序内操作反馈",
                isOn: Binding(
                    get: { store.showActionNotifications },
                    set: { store.setActionNotifications($0) }
                )
            )
            .padding(.top, 27)
            .offset(y: -2)

            Text("叠加")
                .font(AppTypography.title)
                .settingsSectionTitleOpticalBounds()
                .padding(.top, 30)
                .offset(y: -1.5)

            NotificationSwitchRow(
                title: "低电量通知",
                isOn: Binding(
                    get: { store.showLowBatteryNotifications },
                    set: { store.setLowBatteryNotifications($0) }
                )
            )
            .padding(.top, 27)
            .offset(y: -0.5)

            NotificationSwitchRow(
                title: "权限提醒",
                isOn: Binding(
                    get: { store.showPermissionReminders },
                    set: { store.setPermissionReminders($0) }
                )
            )
            .padding(.top, 24)
            .offset(y: 2)

            NotificationSwitchRow(
                title: "遥控器连接状态通知",
                isOn: Binding(
                    get: { store.showConnectionNotifications },
                    set: { store.setConnectionNotifications($0) }
                )
            )
            .padding(.top, 24)
        }
    }
}

private struct NotificationSwitchRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(AppTypography.title)
                .settingsSectionTitleOpticalBounds()
            Spacer()
            CompactSettingsToggle(isOn: $isOn, accessibilityLabel: title)
        }
        .frame(width: 555, height: 22)
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        PlainSettingsRow(title: title, subtitle: subtitle) {
            CompactSettingsToggle(isOn: $isOn, accessibilityLabel: title)
        }
    }
}

private struct PrivacySettingsContent: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("隐私与数据")
                .font(AppTypography.pageTitle)
                .settingsPageTitleOpticalBounds()
                .offset(y: SettingsLayoutMetrics.pageTitleOpticalYOffset)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Text("分享使用数据，用于分析")
                        .font(AppTypography.title)
                        .settingsSectionTitleOpticalBounds()
                    Spacer()
                    CompactSettingsToggle(
                        isOn: .constant(false),
                        accessibilityLabel: "分享使用数据已关闭"
                    )
                    .disabled(true)
                    .opacity(0.42)
                }
                .frame(width: 555)
                Text("MiCoding 不包含分析 SDK，不会自动发送诊断、使用数据或按键内容。")
                    .font(AppTypography.body)
                    .foregroundStyle(Color.primary.opacity(0.72))
                    .lineSpacing(3)
                    .padding(.top, 12)

                HStack(spacing: 3) {
                    Text("了解我们的")
                        .font(AppTypography.body)
                        .foregroundStyle(Color.primary.opacity(0.72))
                    Button("隐私说明") { openPrivacyInformation() }
                        .buttonStyle(SettingsTextLinkStyle())
                    Text("。")
                        .font(AppTypography.body)
                        .foregroundStyle(Color.primary.opacity(0.72))
                }
                .padding(.top, 3)
                .offset(y: -5.5)
            }
            .padding(.top, 30)
            .offset(y: -1.5)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Text("推荐")
                        .font(AppTypography.title)
                        .settingsSectionTitleOpticalBounds()
                    Spacer()
                    CompactSettingsToggle(
                        isOn: Binding(
                            get: { store.showExperienceRecommendations },
                            set: { store.setExperienceRecommendations($0) }
                        ),
                        accessibilityLabel: "体验推荐"
                    )
                }
                .frame(width: 555)
                .offset(y: -3.5)

                Text("精选推荐与遥控器相关的体验和操作模板。")
                    .font(AppTypography.body)
                    .foregroundStyle(Color.primary.opacity(0.72))
                    .padding(.top, 12)
            }
            .padding(.top, 24)
            .offset(y: -1.5)

            VStack(alignment: .leading, spacing: 0) {
                Button("本地数据与权限") { revealConfiguration() }
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(Color.primary)
                    .buttonStyle(QuietButtonStyle())

                Text("配置只保存在这台 Mac。MiCoding 仅在用户授权后读取遥控器输入并执行已分配的系统动作。")
                    .font(.custom("AvenirNext-Regular", size: 11))
                    .foregroundStyle(Color.primary.opacity(0.72))
                    .lineSpacing(1)
                    .frame(width: 515, alignment: .leading)
                    .padding(.top, 8)
            }
            .padding(.top, 18)

            Text("系统权限")
                .font(AppTypography.title)
                .settingsSectionTitleOpticalBounds()
                .padding(.top, 30)

            PermissionSettingsRow(
                title: "输入监控",
                subtitle: "读取遥控器的 HID 按键事件",
                granted: store.permissions.inputMonitoringGranted,
                action: {
                    store.requestInputMonitoringPermission()
                    store.openInputMonitoringSettings()
                }
            )
            .padding(.top, 12)

            PermissionSettingsRow(
                title: "辅助功能",
                subtitle: "执行键盘快捷键和系统操作",
                granted: store.permissions.accessibilityGranted,
                action: {
                    store.requestAccessibilityPermission()
                    store.openAccessibilitySettings()
                }
            )

        }
    }

    private func revealConfiguration() {
        let url = LocalConfigurationStore().fileURL
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(url.deletingLastPathComponent())
        }
    }

    private func openPrivacyInformation() {
        guard let url = URL(string: "https://github.com/zhangtuansia/MiCoding#本地数据与权限") else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct AppearanceThemeCard: View {
    let mode: AppAppearanceMode
    let selected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var previewHeight: CGFloat {
        // The reference uses 160 × 90 artwork for system/dark and 161 × 90
        // artwork for light, all rendered at an exact 165 pt width.
        mode == .light ? 165 * (90 / 161) : 165 * (90 / 160)
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                ThemePreview(mode: mode)
                    .frame(width: 165, height: previewHeight)
                    .offset(x: 0.5, y: 0.5)

                ZStack {
                    Circle()
                        .fill(selected ? AppTheme.accent(for: colorScheme) : Color.primary.opacity(0.28))
                        .frame(width: 21, height: 21)
                        .overlay {
                            AppIcon(symbol: "checkmark", size: 11)
                                .foregroundStyle(AppTheme.onAccent(for: colorScheme))
                        }
                }
                .frame(width: 21, height: 21)
                .offset(x: 15, y: previewHeight + 20.95)

                if mode == .system {
                    ZStack(alignment: .topLeading) {
                        Text("跟随操作系统")
                            .tracking(-0.19)
                            .offset(x: 1.8)
                        Text("主题")
                            .scaleEffect(x: 0.94, y: 1, anchor: .topLeading)
                            .offset(y: 13.5)
                    }
                    .font(AppTypography.supportingMedium)
                    .frame(width: 92, height: 29, alignment: .topLeading)
                    .offset(x: 50.1, y: previewHeight + 17.75)
                } else {
                    Text(mode.title)
                        .font(AppTypography.supportingMedium)
                        .scaleEffect(
                            x: mode == .light ? 0.992 : 1,
                            y: mode == .light ? 1.02 : 1,
                            anchor: .topLeading
                        )
                        .offset(
                            x: mode == .light ? 50.25 : 50,
                            y: previewHeight + (mode == .light ? 32.05 : 32.4)
                        )
                }
            }
            .foregroundStyle(Color.primary)
            .frame(width: 166, height: 152, alignment: .topLeading)
            .background(AppTheme.primarySurface(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        selected ? Color.clear : AppTheme.controlBorder(for: colorScheme),
                        lineWidth: 1
                    )
            }
            .overlay {
                if selected {
                    // Options+ paints the selected outline outside the DOM
                    // button bounds. The negative inset reproduces that 2 pt
                    // halo while keeping all three hit targets identical.
                    RoundedRectangle(cornerRadius: 9.5, style: .continuous)
                        .stroke(AppTheme.accent(for: colorScheme), lineWidth: 2)
                        .padding(-1.5)
                }
            }
        }
        .buttonStyle(QuietButtonStyle())
    }
}

private struct ThemePreview: View {
    let mode: AppAppearanceMode

    var body: some View {
        GeometryReader { proxy in
            let naturalWidth: CGFloat = mode == .light ? 161 : 160
            let scaleX = proxy.size.width / naturalWidth
            let scaleY = proxy.size.height / 90

            ZStack(alignment: .topLeading) {
                previewBackground

                switch mode {
                case .system:
                    previewPanel(color: .white, x: 33, width: 80, scaleX: scaleX, scaleY: scaleY)
                    previewPanel(color: previewDarkPanel, x: 78, width: 82, scaleX: scaleX, scaleY: scaleY)
                    previewLines(
                        x: 44,
                        y: 47,
                        widths: [34, 27, 34],
                        colors: [previewLightLine, AppTheme.purple, previewLightLine],
                        scaleX: scaleX,
                        scaleY: scaleY
                    )
                    previewLines(
                        x: 89,
                        y: 47,
                        widths: [40, 27, 50],
                        colors: [previewDarkLine, previewMint, previewDarkLine],
                        scaleX: scaleX,
                        scaleY: scaleY
                    )

                case .light:
                    previewPanel(color: .white, x: 46, width: 115, scaleX: scaleX, scaleY: scaleY)
                    previewLines(
                        x: 57,
                        y: 47,
                        widths: [40, 27, 50],
                        colors: [previewLightLine, AppTheme.purple, previewLightLine],
                        scaleX: scaleX,
                        scaleY: scaleY
                    )

                case .dark:
                    previewPanel(color: previewDarkPanel, x: 45, width: 115, scaleX: scaleX, scaleY: scaleY)
                    previewLines(
                        x: 57,
                        y: 52,
                        widths: [39, 26, 49],
                        colors: [previewDarkLine, previewMint, previewDarkLine],
                        scaleX: scaleX,
                        scaleY: scaleY
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 8 * scaleX, style: .continuous))
        }
        .clipped()
    }

    @ViewBuilder
    private var previewBackground: some View {
        switch mode {
        case .system:
            HStack(spacing: 0) {
                lightPreviewBackground
                darkPreviewBackground
            }
        case .light:
            lightPreviewBackground
        case .dark:
            darkPreviewBackground
        }
    }

    private var lightPreviewBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 209 / 255, green: 222 / 255, blue: 241 / 255),
                Color(red: 150 / 255, green: 187 / 255, blue: 226 / 255)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var darkPreviewBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 34 / 255, green: 52 / 255, blue: 76 / 255),
                Color(red: 61 / 255, green: 87 / 255, blue: 120 / 255)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var previewDarkPanel: Color {
        Color(red: 34 / 255, green: 36 / 255, blue: 37 / 255)
    }

    private var previewLightLine: Color {
        Color(red: 204 / 255, green: 204 / 255, blue: 204 / 255)
    }

    private var previewDarkLine: Color {
        Color(red: 89 / 255, green: 91 / 255, blue: 91 / 255)
    }

    private var previewMint: Color {
        Color(red: 51 / 255, green: 238 / 255, blue: 217 / 255)
    }

    private func previewPanel(
        color: Color,
        x: CGFloat,
        width: CGFloat,
        scaleX: CGFloat,
        scaleY: CGFloat
    ) -> some View {
        RoundedRectangle(cornerRadius: 8 * scaleX, style: .continuous)
            .fill(color)
            .frame(width: width * scaleX, height: 70 * scaleY)
            .shadow(color: Color.black.opacity(0.10), radius: 4 * scaleX)
            .offset(x: x * scaleX, y: 26 * scaleY)
    }

    private func previewLines(
        x: CGFloat,
        y: CGFloat,
        widths: [CGFloat],
        colors: [Color],
        scaleX: CGFloat,
        scaleY: CGFloat
    ) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(widths.indices), id: \.self) { index in
                Capsule()
                    .fill(colors[index])
                    .frame(width: widths[index] * scaleX, height: 6 * scaleY)
                    .offset(y: CGFloat(index) * 10 * scaleY)
            }
        }
        .offset(x: x * scaleX, y: y * scaleY)
    }
}

private struct SettingsSidebarItem: View {
    let section: SettingsSection
    let selected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text(section.title)
                    .font(AppTypography.settingsNavigation)
                Spacer()
            }
            .foregroundStyle(selected ? AppTheme.accent(for: colorScheme) : Color.primary)
            .padding(.leading, 38)
            .padding(.trailing, 18)
            .frame(width: 300, height: 44.5, alignment: .leading)
            .contentShape(Rectangle())
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(selected ? AppTheme.accent(for: colorScheme) : .clear)
                    .frame(width: 4)
                    .offset(x: -1.5)
            }
        }
        .buttonStyle(QuietButtonStyle())
        .offset(x: -25)
    }
}

private struct SettingsTextLinkStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyMedium)
            .foregroundStyle(AppTheme.accent(for: colorScheme).opacity(configuration.isPressed ? 0.62 : 1))
            .frame(height: 28)
            .scaleEffect(
                x: SettingsLayoutMetrics.textLinkOpticalXScale,
                y: 1,
                anchor: .leading
            )
            .offset(y: SettingsLayoutMetrics.textLinkOpticalYOffset)
    }
}

private struct SettingsPage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(AppTypography.pageTitle)
                .settingsPageTitleOpticalBounds()
            Text(subtitle)
                .font(AppTypography.body)
                .foregroundStyle(Color.primary.opacity(0.72))
                .padding(.top, 8)

            VStack(spacing: 0) { content }
                .padding(.top, 26)
        }
    }
}

private struct SettingsLine: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Color.clear
            .frame(height: 14)
    }
}

private struct PlainSettingsRow<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppTypography.bodyMedium)
                Text(subtitle)
                    .font(AppTypography.supporting)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
            trailing
        }
        .frame(minHeight: 58)
    }
}

private struct CompactSettingsToggle: View {
    @Binding var isOn: Bool
    var accessibilityLabel = "设置开关"

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Capsule()
                .fill(
                    isOn
                        ? AppTheme.accent(for: colorScheme)
                        : Color.primary.opacity(colorScheme == .dark ? 0.28 : 0.20)
                )
                .frame(width: 28, height: 16)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(AppTheme.primarySurface(for: colorScheme))
                        .frame(width: 12, height: 12)
                        .padding(2)
                }
        }
        .buttonStyle(QuietButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isOn ? "已开启" : "已关闭")
    }
}

private struct PermissionSettingsRow: View {
    let title: String
    let subtitle: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        PlainSettingsRow(title: title, subtitle: subtitle) {
            if granted {
                Label {
                    Text("已允许")
                } icon: {
                    AppIcon(symbol: "checkmark.circle.fill", size: AppIconSize.control)
                }
                    .font(AppTypography.label)
                    .foregroundStyle(AppTheme.success)
            } else {
                Button("允许") { action() }
                    .buttonStyle(InlineActionButtonStyle())
            }
        }
    }
}
