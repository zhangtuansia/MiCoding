import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AppShellView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    private let deviceInformationTimer = Timer.publish(
        every: 60,
        on: .main,
        in: .common
    ).autoconnect()

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.canvas(for: colorScheme)
                .ignoresSafeArea()

            Group {
                if store.showsFeatureOverview {
                    DeviceFeatureOverviewView()
                        .ignoresSafeArea()
                } else if store.showsExploreCenter {
                    ExploreCenterView()
                } else if store.showsActionsRing {
                    ActionsRingView()
                } else if store.showsConnectionTypePicker {
                    ConnectionTypePickerView()
                } else if store.activeDeviceID != nil {
                    DeviceDetailView(device: .remote2Pro)
                } else {
                    sectionContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if store.showsActionsRing {
                Button("") {
                    store.navigateBackFromActionsRing()
                }
                .keyboardShortcut(.cancelAction)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
                .zIndex(25)
            }

            if let toastMessage = store.toastMessage {
                ToastView(message: toastMessage, tone: store.toastTone)
                    .padding(.top, 18)
                    .transition(.opacity)
                    .zIndex(20)
            }

            if store.showsAIPromptNotice {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { store.dismissAIPromptNotice() }
                    .zIndex(26)

                AIPromptNoticeCard()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 87)
                    .padding(.trailing, 95)
                    .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
                    .zIndex(27)
            }

            if store.showsLocalProfile {
                Button("") {
                    store.dismissLocalProfile()
                }
                .keyboardShortcut(.cancelAction)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
                .zIndex(32)

                Color.black.opacity(0.52)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { store.dismissLocalProfile() }
                    .transition(.opacity)
                    .zIndex(30)

                LocalProfileModal()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .offset(y: -16)
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
                    .zIndex(31)
            }
        }
        .animation(.easeOut(duration: 0.14), value: store.toastMessage)
        .animation(.easeOut(duration: 0.16), value: store.showsLocalProfile)
        .animation(.easeOut(duration: 0.14), value: store.showsAIPromptNotice)
        .onExitCommand {
            if store.showsAIPromptNotice {
                store.dismissAIPromptNotice()
            } else if store.showsFeatureOverview {
                store.dismissFeatureOverview()
            } else if store.showsExploreCenter {
                store.dismissExploreCenter()
            } else if store.showsActionsRing {
                store.navigateBackFromActionsRing()
            } else if store.showsLocalProfile {
                store.dismissLocalProfile()
            } else if store.showsConnectionTypePicker {
                store.cancelAddingDevice()
            } else if store.activeSection == .settings {
                store.leaveSettings()
            } else if store.activeDeviceID != nil {
                if store.selectedSlotID != nil {
                    store.closeActionLibrary()
                } else if store.showsApplicationPicker {
                    store.closeApplicationPicker()
                } else {
                    store.closeDevice()
                }
            } else {
                store.cancelDragging()
            }
        }
        .onAppear { store.startBackend() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.refreshRuntimeState()
        }
        .onReceive(deviceInformationTimer) { _ in
            store.refreshDeviceInformation()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showActionsRingRequested)) { _ in
            store.showRuntimeActionsRing()
        }
        .onDisappear { store.stopBackend() }
        // Read the published appearance preference inside the live SwiftUI
        // hierarchy. Applying this only once while constructing NSHostingView
        // made theme changes appear after relaunch instead of immediately.
        .preferredColorScheme(store.preferredColorScheme)
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch store.activeSection {
        case .devices:
            HomeView()
        case .automations:
            SmartActionsView()
        case .settings:
            SettingsView()
        }
    }
}

struct RootToolbar: View {
    let title: String
    var eyebrow: String?

    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                if let eyebrow {
                    Text(eyebrow)
                        .font(AppTypography.label)
                        .tracking(0.7)
                        .foregroundStyle(.secondary)
                }
                Text(title)
                    .font(AppTypography.display)
                    .tracking(0)
                    .foregroundStyle(AppTheme.text(for: colorScheme))
                    .offset(
                        y: eyebrow == nil
                            ? HomeToolbarLayoutMetrics.greetingYOffset
                            : 0
                    )
                    .scaleEffect(
                        x: HomeToolbarLayoutMetrics.greetingWidthScale,
                        y: HomeToolbarLayoutMetrics.greetingHeightScale,
                        anchor: .topLeading
                    )
            }

            Spacer()

            HomeToolbar()
        }
        .padding(.horizontal, 40)
        .padding(.top, 18)
        .frame(height: AppMetrics.heroHeaderHeight)
        .offset(y: -9)
    }
}

enum HomeToolbarLayoutMetrics {
    // The Options+ toolbar baseline sits 5.5 pt below the unadjusted SwiftUI
    // strip. Keep this independent from RootToolbar so the already-aligned
    // greeting and home cards do not move with it.
    static let opticalXOffset: CGFloat = -4
    static let opticalYOffset: CGFloat = -2
    static let greetingWidthScale: CGFloat = 1
    static let greetingHeightScale: CGFloat = 1
    static let greetingYOffset: CGFloat = 0.5
    static let trailingIconGap: CGFloat = 8
    static let settingsIconSize: CGFloat = 22
    static let settingsIconXScale: CGFloat = 1.11
}

private struct HomeToolbar: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            homeIconButton(
                symbol: "checkmark.circle",
                help: "Smart Actions"
            ) {
                store.selectSection(.automations)
            }

            Color.clear
                .frame(width: HomeToolbarLayoutMetrics.trailingIconGap)

            homeIconButton(symbol: "gearshape", help: "设置") {
                store.selectSection(.settings)
            }
        }
        .foregroundStyle(colorScheme == .dark ? AppTheme.text(for: colorScheme) : .black)
        .frame(width: 104, height: 48)
        .offset(
            x: HomeToolbarLayoutMetrics.opticalXOffset,
            y: HomeToolbarLayoutMetrics.opticalYOffset
        )
    }

    private func homeIconButton(
        symbol: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            AppIcon(
                symbol: symbol,
                size: symbol == "gearshape" ? HomeToolbarLayoutMetrics.settingsIconSize : 24
            )
                .scaleEffect(
                    x: symbol == "gearshape" ? HomeToolbarLayoutMetrics.settingsIconXScale : 1,
                    y: 1
                )
                .offset(y: -2)
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(QuietButtonStyle())
        .help(help)
        .accessibilityLabel(help)
    }
}

private struct AIPromptNoticeCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    private let capabilities = ["摘要", "翻译", "代码解释"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("本地文本工作流")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.text(for: colorScheme))

            Text("从本地模板创建摘要、翻译和代码解释动作。\n配置仅保存在这台 Mac，可直接分配给遥控器。")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            HStack(spacing: 8) {
                ForEach(capabilities, id: \.self) { capability in
                    Text(capability)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.text(for: colorScheme).opacity(0.78))
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(AppTheme.elevatedSurface(for: colorScheme).opacity(0.58))
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 16)

            Button {
                store.showAIWorkflowTemplates()
            } label: {
                HStack(spacing: 7) {
                    Text("浏览工作流")
                    AppIcon(symbol: "arrow.right", size: 13)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .padding(.top, 18)
        }
        .padding(20)
        .frame(width: 320, alignment: .topLeading)
        .background(AppTheme.primarySurface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
        }
        .overlay(alignment: .top) {
            AIPromptPopoverArrow()
                .fill(AppTheme.primarySurface(for: colorScheme))
                .frame(width: 20, height: 10)
                .offset(y: -9)
        }
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.34 : 0.13),
            radius: 18,
            y: 9
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("本地文本工作流")
    }
}

private struct AIPromptPopoverArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct LocalProfileModal: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showsProfileActions = false
    @State private var pendingBackupData: Data?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("本地配置")
                    .font(.system(size: 20, weight: .bold))
                    .tracking(0.75)

                Spacer()
            }
            .frame(height: 28)
            .padding(.horizontal, 32)
            .padding(.top, 24)

            HStack(spacing: 30) {
                AppIcon(symbol: "user", size: 25)
                    .frame(width: 34, height: 34)

                Text("本地配置与备份")
                    .font(.custom("AvenirNext-DemiBold", size: 15))
                    .offset(y: 1)

                Spacer()
            }
            .frame(height: 34)
            .padding(.horizontal, 32)
            .padding(.top, 48)

            Text("配置保存在此 Mac；可导出或恢复备份。")
                .font(.custom("AvenirNext-Regular", size: 14))
                .foregroundStyle(Color.primary.opacity(0.66))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.top, 10)

            Button {
                showsProfileActions = true
            } label: {
                Text("管理本地配置")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppTheme.onAccent(for: colorScheme))
                    .frame(maxWidth: .infinity, minHeight: 50, maxHeight: 50)
                    .background(AppTheme.accent(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            .buttonStyle(QuietButtonStyle())
            .padding(.horizontal, 32)
            .padding(.top, 24)
        }
        .frame(width: 400, height: 272, alignment: .top)
        .background(AppTheme.surface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Button {
                store.dismissLocalProfile()
            } label: {
                AppIcon(symbol: "x", size: 20)
                    .frame(width: 32, height: 35)
                    .contentShape(Rectangle())
            }
            .buttonStyle(QuietButtonStyle())
            .accessibilityLabel("关闭本地配置")
            .padding(.top, 16)
            .padding(.trailing, 20)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.38 : 0.22), radius: 24, y: 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("本地配置与备份")
        .confirmationDialog(
            "管理本地配置",
            isPresented: $showsProfileActions,
            titleVisibility: .visible
        ) {
            Button("导出本地配置…") { exportLocalProfile() }
            Button("导入本地配置…") { importLocalProfile() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("配置仅保存在这台 Mac。")
        }
        .confirmationDialog(
            "恢复此备份？",
            isPresented: Binding(
                get: { pendingBackupData != nil },
                set: { if !$0 { pendingBackupData = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("恢复并覆盖当前配置", role: .destructive) {
                restorePendingLocalProfile()
            }
            Button("取消", role: .cancel) { pendingBackupData = nil }
        } message: {
            Text("当前本地配置会被备份内容替换。")
        }
    }

    private func exportLocalProfile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.message = "保存 Xiaomi Remote 2 Pro 的本地配置备份"
        panel.nameFieldStringValue = "MiCoding-Xiaomi-Remote-2-Pro-Backup.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try store.makeDeviceBackupData().write(to: url, options: .atomic)
            store.dismissLocalProfile()
            store.showToast("本地配置已导出")
        } catch {
            store.showImportantToast("导出失败：\(error.localizedDescription)")
        }
    }

    private func importLocalProfile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "选择 MiCoding 设备配置备份"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            pendingBackupData = try Data(contentsOf: url)
        } catch {
            store.showImportantToast("导入失败：\(error.localizedDescription)")
        }
    }

    private func restorePendingLocalProfile() {
        guard let data = pendingBackupData else { return }
        pendingBackupData = nil
        do {
            try store.restoreDeviceBackupData(data)
            store.dismissLocalProfile()
            store.showToast("本地配置已恢复")
        } catch {
            store.showImportantToast("导入失败：\(error.localizedDescription)")
        }
    }
}
