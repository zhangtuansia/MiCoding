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
                ToastView(message: toastMessage)
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
    var showAddDevice = false

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
                    .tracking(showAddDevice ? 0 : -0.7)
                    .foregroundStyle(AppTheme.text(for: colorScheme))
                    .offset(
                        y: eyebrow == nil && showAddDevice
                            ? HomeToolbarLayoutMetrics.greetingYOffset
                            : 0
                    )
                    .scaleEffect(
                        x: showAddDevice ? HomeToolbarLayoutMetrics.greetingWidthScale : 1,
                        y: showAddDevice ? HomeToolbarLayoutMetrics.greetingHeightScale : 1,
                        anchor: .topLeading
                    )
            }

            Spacer()

            if showAddDevice {
                HomeToolbar()
            }
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
    static let addIconSize: CGFloat = 22
    static let addIconXOffset: CGFloat = -2
    static let addTextXOffset: CGFloat = -0.5
    static let visibleToolbarWidth: CGFloat = 251
    static let trailingIconGap: CGFloat = 8
    static let settingsIconSize: CGFloat = 22
    static let settingsIconXScale: CGFloat = 1.11
}

private struct HomeToolbar: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            Button {
                store.beginAddingDevice()
            } label: {
                HStack(spacing: 8) {
                    AppIcon(symbol: "plus", size: HomeToolbarLayoutMetrics.addIconSize)
                        .offset(x: HomeToolbarLayoutMetrics.addIconXOffset, y: -2)
                    Text("添加设备")
                        .font(.custom("AvenirNext-Bold", size: 14))
                        .offset(x: HomeToolbarLayoutMetrics.addTextXOffset, y: 0.5)
                }
                .frame(width: 112, height: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(QuietButtonStyle())
            .help("添加设备")
            .accessibilityLabel("添加设备")

            toolbarGap(width: 35)

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
        .frame(width: HomeToolbarLayoutMetrics.visibleToolbarWidth, height: 48)
        .offset(
            x: HomeToolbarLayoutMetrics.opticalXOffset,
            y: HomeToolbarLayoutMetrics.opticalYOffset
        )
    }

    private func toolbarGap(width: CGFloat) -> some View {
        Rectangle()
            .fill(AppTheme.separator(for: colorScheme))
            .frame(width: 1, height: 24)
            .frame(width: width)
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

    var body: some View {
        VStack(spacing: 0) {
            AIPromptBuilderIllustration()
                .frame(width: 332, height: 194)

            VStack(alignment: .leading, spacing: 0) {
                Text("AI 工作流已整合到\nSmart Actions")
                    .font(.custom("AvenirNext-Bold", size: 18))
                    .tracking(-0.12)
                    .lineSpacing(-4)
                    .fixedSize(horizontal: false, vertical: true)
                    .scaleEffect(x: 1, y: 0.92, anchor: .top)

                Text("从本地模板创建 AI 回复、摘要、翻译和代码解释工作流。所有配置只保存在这台 Mac。")
                    .font(.custom("AvenirNext-Regular", size: 13))
                    .tracking(0.15)
                    // The notice keeps the same black card in both app
                    // appearances. `Color.primary` becomes black in light
                    // mode and made this copy effectively disappear.
                    .foregroundStyle(Color.white.opacity(0.76))
                    .lineSpacing(1.5)
                    .padding(.top, 11)
                    .fixedSize(horizontal: false, vertical: true)
                    .offset(y: -4)

                Button {
                    store.showAIWorkflowTemplates()
                } label: {
                    HStack(spacing: 7) {
                        Text("浏览 AI 模板")
                            .font(.custom("AvenirNext-Bold", size: 13))
                        AppIcon(symbol: "arrow.right", size: 12)
                    }
                    .foregroundStyle(Color.black.opacity(0.86))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(AppTheme.mint)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                .buttonStyle(QuietButtonStyle())
                .padding(.top, 19)
                .offset(y: -4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 17)
            .frame(width: 332, height: 216, alignment: .topLeading)
            .background(Color(white: 0.09))
        }
        .foregroundStyle(.white)
        .frame(width: 332, height: 410, alignment: .top)
        .background(Color(white: 0.09))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .top) {
            AIPromptPopoverArrow()
                .fill(Color(red: 0.72, green: 0.95, blue: 0.94))
                .frame(width: 22, height: 12)
                .offset(y: -10)
        }
        .shadow(color: .black.opacity(0.30), radius: 20, y: 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("AI 工作流")
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

private struct AIPromptBuilderIllustration: View {
    var body: some View {
        ZStack {
            Color(red: 0.72, green: 0.95, blue: 0.94)

            VStack(spacing: 0) {
                HStack(spacing: 5) {
                    AppIcon(symbol: "sparkles", size: 7)
                    Text("MiCoding AI Workflows")
                        .font(.system(size: 6, weight: .semibold))
                    Spacer()
                    Circle().stroke(lineWidth: 0.7).frame(width: 10, height: 10)
                    Circle().stroke(lineWidth: 0.7).frame(width: 10, height: 10)
                    Circle().fill(Color.black.opacity(0.55)).frame(width: 10, height: 10)
                }
                .foregroundStyle(Color.white.opacity(0.88))
                .padding(.horizontal, 6)
                .frame(height: 20)
                .background(Color(red: 0.23, green: 0.33, blue: 0.32))

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("工作流")
                            .font(.system(size: 7, weight: .semibold))
                        Label("回复消息", systemImage: "arrow.clockwise")
                            .foregroundStyle(AppTheme.mint)
                        Label("汇总文本", systemImage: "doc.text")
                        Label("翻译文本", systemImage: "arrowshape.turn.up.left")
                        Label("解释代码", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    .font(.system(size: 6, weight: .medium))
                    .padding(7)
                    .frame(width: 86)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                    .background(Color.black)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("工作流说明")
                            .font(.system(size: 7, weight: .semibold))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.black)
                            .frame(height: 18)
                            .overlay(alignment: .leading) {
                                Text("处理当前选择的文本")
                                    .font(.system(size: 5.5))
                                    .padding(.horizontal, 5)
                            }
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.black)
                            .frame(height: 50)
                            .overlay(alignment: .topLeading) {
                                Text("在 Smart Actions 中选择模板，\n再分配给遥控器按键。")
                                    .font(.system(size: 5.5))
                                    .lineSpacing(1)
                                    .padding(5)
                            }
                        HStack(spacing: 4) {
                            promptChip("模板")
                            promptChip("动作")
                            Spacer()
                            Circle()
                                .fill(Color.black)
                                .frame(width: 18, height: 18)
                                .overlay {
                                    AppIcon(symbol: "arrow.right", size: 7)
                                        .foregroundStyle(AppTheme.mint)
                                }
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(7)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Color(red: 0.45, green: 0.55, blue: 0.54))
                }
            }
            .frame(width: 250, height: 128)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color.black.opacity(0.28), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
    }

    private func promptChip(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 5.5, weight: .medium))
            .padding(.horizontal, 5)
            .frame(height: 14)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
    }
}

private struct LocalProfileModal: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showsProfileActions = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("帐户")
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
            .accessibilityLabel("关闭帐户")
            .padding(.top, 16)
            .padding(.trailing, 20)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.38 : 0.22), radius: 24, y: 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("帐户与本地配置")
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
            store.showToast("导出失败：\(error.localizedDescription)")
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
            try store.restoreDeviceBackupData(Data(contentsOf: url))
            store.dismissLocalProfile()
            store.showToast("本地配置已恢复")
        } catch {
            store.showToast("导入失败：\(error.localizedDescription)")
        }
    }
}
