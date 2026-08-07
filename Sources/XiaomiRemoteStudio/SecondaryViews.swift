import AppKit
import SwiftUI

private enum AutomationFilter: String, CaseIterable, Identifiable {
    case all
    case focus
    case meeting
    case productivity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .focus: "专注"
        case .meeting: "会议"
        case .productivity: "效率"
        }
    }

    var symbol: String {
        switch self {
        case .all: "rectangle.3.group"
        case .focus: "moon.stars.fill"
        case .meeting: "video.fill"
        case .productivity: "square.and.pencil"
        }
    }

    func includes(_ action: SmartAction) -> Bool {
        switch self {
        case .all: true
        case .focus: action.id == "focus"
        case .meeting: action.id == "meeting"
        case .productivity: action.id == "note"
        }
    }

    static func category(for action: SmartAction) -> String {
        switch action.id {
        case "focus": "专注"
        case "meeting": "会议"
        default: "效率"
        }
    }
}

struct SmartActionsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var actions: [SmartAction]
    @State private var searchText = ""
    @State private var selection: AutomationFilter = .all
    @State private var showsGuide = true

    init(actions: [SmartAction] = SmartAction.samples) {
        _actions = State(initialValue: actions)
    }

    var body: some View {
        VStack(spacing: 0) {
            AutomationToolbar(searchText: $searchText)

            HStack(spacing: 0) {
                AutomationSidebar(selection: $selection)

                Rectangle()
                    .fill(AppTheme.separator(for: colorScheme))
                    .frame(width: 1)

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if showsGuide {
                            AutomationGuideBanner {
                                showsGuide = false
                            }
                        }

                        HStack(alignment: .firstTextBaseline) {
                            Text("组合动作")
                                .font(AppTypography.sectionTitle)
                                .tracking(-0.25)

                            Spacer()

                            if !actions.isEmpty {
                                Text("\(filteredActions.count) 个")
                                    .font(AppTypography.supportingMedium)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if actions.isEmpty {
                            EmptySmartActionsView {
                                actions = SmartAction.samples
                            }
                        } else if filteredActions.isEmpty {
                            EmptyAutomationSearchView {
                                searchText = ""
                                selection = .all
                            }
                        } else {
                            LazyVGrid(
                                columns: Array(
                                    repeating: GridItem(.flexible(), spacing: 18),
                                    count: 3
                                ),
                                spacing: 18
                            ) {
                                ForEach(filteredActions) { action in
                                    SmartActionCard(action: action)
                                }
                            }
                        }

                        AutomationPrivacyNote()
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 28)
                    .padding(.bottom, 40)
                    .frame(maxWidth: 1_080, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(AppTheme.canvas(for: colorScheme))
    }

    private var filteredActions: [SmartAction] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return actions.filter { action in
            selection.includes(action)
                && (query.isEmpty
                    || action.title.localizedCaseInsensitiveContains(query)
                    || action.subtitle.localizedCaseInsensitiveContains(query))
        }
    }
}

private struct AutomationToolbar: View {
    @Binding var searchText: String

    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            ToolbarItemButton(symbol: "chevron.left", title: "") {
                store.selectSection(.devices)
            }
            .help("返回设备")

            Text("智能操作")
                .font(AppTypography.pageTitle)
                .tracking(-0.45)

            Spacer(minLength: 24)

            HStack(spacing: 9) {
                AppIcon(symbol: "magnifyingglass", size: AppIconSize.control)
                    .foregroundStyle(.secondary)

                TextField("搜索组合动作", text: $searchText)
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
            }
            .padding(.horizontal, 12)
            .frame(width: 252, height: AppMetrics.controlHeight)
            .background(AppTheme.surface(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.radiusControl, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppMetrics.radiusControl, style: .continuous)
                    .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
            }

            Button("配置按键") {
                store.openDevice(.remote2Pro)
            }
            .buttonStyle(PrimaryActionButtonStyle())

            Rectangle()
                .fill(AppTheme.separator(for: colorScheme))
                .frame(width: 1, height: 24)

            ToolbarItemButton(symbol: "gearshape", title: "") {
                store.selectSection(.settings)
            }
            .help("设置")
        }
        .padding(.horizontal, 28)
        .frame(height: AppMetrics.headerHeight)
        .background(AppTheme.surface(for: colorScheme))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.separator(for: colorScheme))
                .frame(height: 1)
        }
    }
}

private struct AutomationSidebar: View {
    @Binding var selection: AutomationFilter

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("浏览")
                .font(AppTypography.label)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 7)

            ForEach(AutomationFilter.allCases) { filter in
                Button {
                    selection = filter
                } label: {
                    HStack(spacing: 10) {
                        AppIcon(symbol: filter.symbol, size: AppIconSize.control)
                        Text(filter.title)
                            .font(AppTypography.bodyMedium)
                    }
                    .foregroundStyle(
                        selection == filter
                            ? AppTheme.accent(for: colorScheme)
                            : Color.primary.opacity(0.72)
                    )
                    .padding(.horizontal, 11)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                    .background(
                        selection == filter
                            ? AppTheme.elevatedSurface(for: colorScheme).opacity(0.82)
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppMetrics.radiusSmall, style: .continuous))
                    .overlay(alignment: .leading) {
                        if selection == filter {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(AppTheme.accent(for: colorScheme))
                                .frame(width: 3, height: 20)
                        }
                    }
                }
                .buttonStyle(QuietButtonStyle())
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 24)
        .padding(.bottom, 22)
        .frame(width: 152)
        .background(AppTheme.surface(for: colorScheme).opacity(0.48))
    }
}

private struct AutomationGuideBanner: View {
    let dismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            AppIcon(symbol: "checkmark.shield.fill", size: AppIconSize.row)
                .foregroundStyle(AppTheme.accent(for: colorScheme))

            VStack(alignment: .leading, spacing: 3) {
                Text("在这台 Mac 上执行")
                    .font(AppTypography.label)

                Text("先运行确认效果，再把组合动作分配给遥控器按键。")
                    .font(AppTypography.supporting)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            Button(action: dismiss) {
                AppIcon(symbol: "xmark", size: AppIconSize.control)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(QuietButtonStyle())
            .help("关闭提示")
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 60)
        .background(AppTheme.surface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.radiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppMetrics.radiusSmall, style: .continuous)
                .stroke(AppTheme.separator(for: colorScheme).opacity(0.72), lineWidth: 1)
        }
    }
}

private struct SmartActionCard: View {
    let action: SmartAction

    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var didRun = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 9) {
                    ForEach(Array(stepVisuals.enumerated()), id: \.offset) { index, visual in
                        AutomationStepIcon(visual: visual)

                        if index < stepVisuals.count - 1 {
                            Rectangle()
                                .fill(AppTheme.separator(for: colorScheme))
                                .frame(width: 1, height: 17)
                        }
                    }
                }

                Text(action.title)
                    .font(.system(size: 18, weight: .semibold))
                    .tracking(-0.12)
                    .padding(.top, 26)

                Text(action.subtitle)
                    .font(AppTypography.body)
                    .foregroundStyle(Color.primary.opacity(0.70))
                    .lineLimit(2)
                    .padding(.top, 9)

                Spacer(minLength: 20)

                Text(AutomationFilter.category(for: action))
                    .font(AppTypography.supportingMedium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(AppTheme.elevatedSurface(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, minHeight: 194, alignment: .topLeading)

            Rectangle()
                .fill(AppTheme.separator(for: colorScheme))
                .frame(height: 1)

            Button {
                run()
            } label: {
                HStack(spacing: 7) {
                    AppIcon(symbol: didRun ? "checkmark" : "play.fill", size: AppIconSize.indicator)
                    Text(didRun ? "已运行" : "运行")
                        .font(AppTypography.bodyMedium)
                }
                .foregroundStyle(didRun ? AppTheme.success : AppTheme.accent(for: colorScheme))
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    (didRun ? AppTheme.success : AppTheme.accent(for: colorScheme))
                        .opacity(didRun ? 0.075 : 0)
                )
            }
            .buttonStyle(QuietButtonStyle())
            .help("运行\(action.title)")
        }
        .background(AppTheme.surface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.radiusSmall, style: .continuous))
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.14 : 0.045),
            radius: 10,
            x: 1,
            y: 4
        )
    }

    private var stepVisuals: [AutomationStepVisual] {
        switch action.id {
        case "focus": [
            .application("/System/Applications/Music.app"),
            .symbol("playpause.fill"),
            .symbol("macwindow")
        ]
        case "meeting": [
            .application("/System/Applications/Calendar.app"),
            .application("/System/Applications/FaceTime.app"),
            .symbol("speaker.slash.fill")
        ]
        case "note": [
            .application("/System/Applications/Notes.app"),
            .symbol("plus")
        ]
        default: [.symbol(action.symbol)]
        }
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
}

private struct AutomationStepIcon: View {
    let visual: AutomationStepVisual

    var body: some View {
        Group {
            switch visual {
            case let .application(path):
                if let icon = Self.applicationIcon(at: path) {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .scaledToFit()
                }
            case let .symbol(symbol):
                AppIcon(symbol: symbol, size: AppIconSize.row)
                    .foregroundStyle(Color.primary.opacity(0.68))
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
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

private struct EmptySmartActionsView: View {
    let restoreTemplates: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ContentUnavailableView {
            Label {
                Text("暂无组合动作")
            } icon: {
                AppIcon(symbol: "bolt.horizontal.circle", size: 36)
            }
        } description: {
            Text("恢复示例后可以直接运行，也可以分配给遥控器按键。")
        } actions: {
            Button("恢复示例", action: restoreTemplates)
                .buttonStyle(PrimaryActionButtonStyle())
        }
        .frame(maxWidth: .infinity, minHeight: 310)
        .background(AppTheme.surface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.radiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppMetrics.radiusSmall, style: .continuous)
                .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
        }
    }
}

private struct EmptyAutomationSearchView: View {
    let clear: () -> Void

    @Environment(\.colorScheme) private var colorScheme

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
        .background(AppTheme.surface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.radiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppMetrics.radiusSmall, style: .continuous)
                .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
        }
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

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var selection: SettingsSection

    init(initialSelection: SettingsSection = .general) {
        _selection = State(initialValue: initialSelection)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ToolbarItemButton(symbol: "chevron.left", title: "") {
                    store.leaveSettings()
                }
                .help("返回")

                Text("应用程序设置")
                    .font(AppTypography.pageTitle)
                    .tracking(-0.45)

                Spacer()
            }
            .padding(.horizontal, 22)
            .frame(height: AppMetrics.headerHeight)
            .background(AppTheme.surface(for: colorScheme))
            .overlay(alignment: .bottom) { separator }

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(SettingsSection.allCases) { section in
                        SettingsSidebarItem(
                            section: section,
                            selected: selection == section
                        ) {
                            selection = section
                        }
                    }

                    Spacer()
                }
                .padding(.top, 18)
                .frame(width: 220)
                .background(AppTheme.surface(for: colorScheme).opacity(0.58))
                .overlay(alignment: .trailing) { separator.frame(width: 1) }

                ScrollView {
                    settingsContent
                        .padding(.horizontal, 54)
                        .padding(.top, 38)
                        .padding(.bottom, 50)
                        .frame(maxWidth: 760, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .background(AppTheme.canvas(for: colorScheme))
    }

    @ViewBuilder
    private var settingsContent: some View {
        switch selection {
        case .general:
            SettingsPage(title: "通用", subtitle: "设备、外观和本机运行状态") {
                PlainSettingsRow(
                    title: "Xiaomi Bluetooth Remote 2 Pro",
                    subtitle: store.connectionState == .connected ? "已通过 HID 后端连接" : "未连接"
                ) {
                    Button("打开蓝牙设置") { store.openBluetoothSettings() }
                        .buttonStyle(InlineActionButtonStyle())
                }

                SettingsLine()

                PlainSettingsRow(
                    title: "输入后端",
                    subtitle: store.backendLog
                ) {
                    Button("重新检测") {
                        store.restartBackend()
                    }
                    .buttonStyle(InlineActionButtonStyle())
                }

                SettingsLine()

                PlainSettingsRow(
                    title: "深色外观",
                    subtitle: "跟随应用内设置"
                ) {
                    Toggle("", isOn: Binding(
                        get: { store.useDarkAppearance },
                        set: { store.setDarkAppearance($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(AppTheme.accent(for: colorScheme))
                }
            }

        case .permissions:
            SettingsPage(title: "设备与权限", subtitle: "遥控器输入和系统操作所需权限") {
                PermissionSettingsRow(
                    title: "输入监控",
                    subtitle: "读取遥控器的 HID 按键事件",
                    granted: store.permissions.inputMonitoringGranted,
                    action: store.requestInputMonitoringPermission
                )

                SettingsLine()

                PermissionSettingsRow(
                    title: "辅助功能",
                    subtitle: "执行键盘快捷键和系统操作",
                    granted: store.permissions.accessibilityGranted,
                    action: store.requestAccessibilityPermission
                )
            }

        case .about:
            SettingsPage(title: "关于", subtitle: "MiCoding") {
                PlainSettingsRow(title: "版本", subtitle: "本机原生应用") {
                    Text(appVersion)
                        .font(AppTypography.supporting)
                        .foregroundStyle(.secondary)
                }

                SettingsLine()

                PlainSettingsRow(title: "数据", subtitle: "按键配置只保存在这台 Mac") {
                    EmptyView()
                }
            }
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(AppTheme.separator(for: colorScheme))
            .frame(height: 1)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.0"
    }

}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case permissions
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "通用"
        case .permissions: "设备与权限"
        case .about: "关于"
        }
    }

}

private struct SettingsSidebarItem: View {
    let section: SettingsSection
    let selected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text(section.title)
                    .font(selected ? AppTypography.bodyMedium : AppTypography.body)
                Spacer()
            }
            .foregroundStyle(selected ? AppTheme.accent(for: colorScheme) : Color.primary)
            .padding(.leading, 36)
            .padding(.trailing, 18)
            .frame(height: AppMetrics.settingsSidebarItemHeight)
            .background(
                selected
                    ? AppTheme.elevatedSurface(for: colorScheme).opacity(0.70)
                    : (hovered ? Color.primary.opacity(0.025) : .clear)
            )
            .contentShape(Rectangle())
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(selected ? AppTheme.accent(for: colorScheme) : .clear)
                    .frame(width: 3, height: 34)
            }
        }
        .buttonStyle(QuietButtonStyle())
        .onHover { hovered = $0 }
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
            Text(subtitle)
                .font(AppTypography.supporting)
                .foregroundStyle(.secondary)
                .padding(.top, 5)
                .padding(.bottom, 28)

            VStack(spacing: 0) { content }
                .padding(.horizontal, 20)
                .surfacePanel(cornerRadius: 16, shadow: false)
        }
    }
}

private struct SettingsLine: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle()
            .fill(AppTheme.separator(for: colorScheme))
            .frame(height: 1)
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
        .frame(height: AppMetrics.rowHeight)
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
