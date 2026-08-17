import AppKit
import SwiftUI
import XCTest
@testable import XiaomiRemoteStudio

final class UISnapshotTests: XCTestCase {
    @MainActor
    func testRenderReferenceScreensWhenRequested() throws {
        guard ProcessInfo.processInfo.environment["RENDER_UI_SNAPSHOTS"] == "1" else {
            throw XCTSkip("仅在显式请求时生成 UI 快照")
        }

        let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build/ui-snapshots-native", isDirectory: true)
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let lightStore = makeSnapshotStore()
        lightStore.appearanceMode = .system
        lightStore.useDarkAppearance = false
        try render(view: AppShellView(), store: lightStore, name: "home", into: directory)
        try render(
            view: DeviceConnectionStatusPopover(
                deviceName: RemoteDevice.remote2Pro.name,
                level: 100,
                firmwareVersion: "2671",
                connected: true,
                refresh: {},
                openBluetoothSettings: {}
            ),
            store: lightStore,
            name: "device-connection-status",
            into: directory
        )

        let stoppedHomeStore = makeSnapshotStore()
        stoppedHomeStore.inputServiceEnabled = false
        stoppedHomeStore.backendLog = "MiCoding 输入服务已停用"
        try render(
            view: AppShellView(),
            store: stoppedHomeStore,
            name: "home-input-service-disabled",
            into: directory
        )

        let disconnectedHomeStore = makeSnapshotStore(connected: false)
        disconnectedHomeStore.appearanceMode = .light
        disconnectedHomeStore.useDarkAppearance = false
        try render(
            view: AppShellView(),
            store: disconnectedHomeStore,
            name: "home-disconnected",
            into: directory
        )

        let removedHomeStore = makeSnapshotStore()
        removedHomeStore.removeManagedDevice(openBluetoothSettings: false)
        removedHomeStore.toastMessage = nil
        try render(
            view: AppShellView(),
            store: removedHomeStore,
            name: "home-device-removed",
            into: directory
        )

        let exploreCenterStore = makeSnapshotStore()
        exploreCenterStore.appearanceMode = .light
        exploreCenterStore.useDarkAppearance = false
        exploreCenterStore.showExploreCenter()
        try render(
            view: AppShellView(),
            store: exploreCenterStore,
            name: "explore-center",
            into: directory
        )

        let aiPromptNoticeStore = makeSnapshotStore()
        aiPromptNoticeStore.appearanceMode = .dark
        aiPromptNoticeStore.useDarkAppearance = true
        aiPromptNoticeStore.toggleAIPromptNotice()
        try render(
            view: AppShellView(),
            store: aiPromptNoticeStore,
            name: "home-ai-prompt-notice-dark",
            into: directory
        )

        let lightAIPromptNoticeStore = makeSnapshotStore()
        lightAIPromptNoticeStore.appearanceMode = .light
        lightAIPromptNoticeStore.useDarkAppearance = false
        lightAIPromptNoticeStore.toggleAIPromptNotice()
        try render(
            view: AppShellView(),
            store: lightAIPromptNoticeStore,
            name: "home-ai-prompt-notice-light",
            into: directory
        )

        let localProfileStore = makeSnapshotStore()
        localProfileStore.appearanceMode = .light
        localProfileStore.useDarkAppearance = false
        localProfileStore.showLocalProfile()
        try render(
            view: AppShellView(),
            store: localProfileStore,
            name: "home-local-profile",
            into: directory
        )

        let actionsRingStore = makeSnapshotStore()
        actionsRingStore.appearanceMode = .light
        actionsRingStore.useDarkAppearance = false
        actionsRingStore.showActionsRing()
        try render(
            view: AppShellView(),
            store: actionsRingStore,
            name: "actions-ring-layout",
            into: directory
        )

        actionsRingStore.selectActionsRingSettings(true)
        try render(
            view: AppShellView(),
            store: actionsRingStore,
            name: "actions-ring-settings",
            into: directory
        )
        try render(
            view: ActionsRingSupportView(edit: {}),
            store: actionsRingStore,
            name: "actions-ring-support",
            into: directory
        )

        actionsRingStore.selectActionsRingSettings(false)
        actionsRingStore.editActionsRing()
        try render(
            view: AppShellView(),
            store: actionsRingStore,
            name: "actions-ring-editor",
            into: directory
        )

        let runtimeRingActions = AppStore.defaultActionsRingActionIDs.map { actionID in
            RemoteAction.catalog.first(where: { $0.id == actionID })
        }
        for (size, name) in [
            (ActionsRingSize.small, "actions-ring-runtime-small"),
            (ActionsRingSize.medium, "actions-ring-runtime-medium"),
            (ActionsRingSize.large, "actions-ring-runtime-large")
        ] {
            let side = ActionsRingOverlayController.panelSide(for: size)
            try render(
                view: ZStack {
                    Color(white: 0.92)
                    ActionsRingRuntimeOverlayView(
                        actions: runtimeRingActions,
                        size: size,
                        close: {},
                        select: { _ in }
                    )
                    .frame(width: side, height: side)
                    // Match the real NSPanel boundary so the snapshot catches
                    // labels that would be cropped outside the transparent window.
                    .clipped()
                },
                store: actionsRingStore,
                name: name,
                into: directory
            )
        }
        let folderSide = ActionsRingOverlayController.panelSide(for: .medium)
        try render(
            view: ZStack {
                Color(white: 0.92)
                ActionsRingRuntimeOverlayView(
                    actions: runtimeRingActions,
                    size: .medium,
                    initialFolderID: "actions-ring-folder-work",
                    close: {},
                    select: { _ in }
                )
                .frame(width: folderSide, height: folderSide)
                .clipped()
            },
            store: actionsRingStore,
            name: "actions-ring-runtime-folder",
            into: directory
        )
        let adjustableActions: [RemoteAction?] = [
            RemoteAction.catalog.first(where: { $0.id == "volume-adjust" })
        ] + Array(runtimeRingActions.dropFirst())
        try render(
            view: ZStack {
                Color(white: 0.92)
                ActionsRingRuntimeOverlayView(
                    actions: adjustableActions,
                    size: .medium,
                    initialAdjustingActionID: "volume-adjust",
                    close: {},
                    select: { _ in }
                )
                .frame(width: folderSide, height: folderSide)
                .clipped()
            },
            store: actionsRingStore,
            name: "actions-ring-runtime-adjustment",
            into: directory
        )

        let connectionPickerStore = makeSnapshotStore(connected: false)
        connectionPickerStore.removeManagedDevice(openBluetoothSettings: false)
        connectionPickerStore.toastMessage = nil
        connectionPickerStore.beginAddingDevice()
        try render(
            view: AppShellView(),
            store: connectionPickerStore,
            name: "connection-pairing-searching",
            into: directory
        )

        let pairingConfigurationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-UISnapshots-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("config.json")
        var pairingConfiguration = PersistedConfiguration(assignmentsByProfile: [:])
        pairingConfiguration.remoteIsManaged = false
        try LocalConfigurationStore(fileURL: pairingConfigurationURL).save(pairingConfiguration)
        let discoveredRemoteStore = AppStore(
            configurationStore: LocalConfigurationStore(fileURL: pairingConfigurationURL),
            runtimeServicesEnabled: false,
            initialDeviceSnapshot: BluetoothDeviceSnapshot(
                batteryLevel: 100,
                firmwareVersion: "2671"
            )
        )
        discoveredRemoteStore.permissions = PermissionSnapshot(
            accessibilityGranted: true,
            inputMonitoringGranted: true
        )
        discoveredRemoteStore.beginAddingDevice()
        try render(
            view: AppShellView(),
            store: discoveredRemoteStore,
            name: "connection-pairing-found",
            into: directory
        )

        let recommendationHiddenStore = makeSnapshotStore()
        recommendationHiddenStore.appearanceMode = .light
        recommendationHiddenStore.useDarkAppearance = false
        recommendationHiddenStore.showExperienceRecommendations = false
        try render(
            view: AppShellView(),
            store: recommendationHiddenStore,
            name: "home-recommendation-hidden",
            into: directory
        )

        let permissionRequiredStore = makeSnapshotStore()
        permissionRequiredStore.appearanceMode = .light
        permissionRequiredStore.useDarkAppearance = false
        permissionRequiredStore.permissions = PermissionSnapshot(
            accessibilityGranted: false,
            inputMonitoringGranted: false
        )
        permissionRequiredStore.backendLog = "已检测到遥控器；授予输入监控权限后即可读取按键"
        try render(
            view: AppShellView(),
            store: permissionRequiredStore,
            name: "home-permission-required",
            into: directory
        )

        lightStore.selectSection(.automations)
        try render(view: AppShellView(), store: lightStore, name: "smart-actions", into: directory)

        let aiWorkflowEntryStore = makeSnapshotStore()
        aiWorkflowEntryStore.appearanceMode = .light
        aiWorkflowEntryStore.useDarkAppearance = false
        aiWorkflowEntryStore.showAIWorkflowTemplates()
        try render(
            view: AppShellView(),
            store: aiWorkflowEntryStore,
            name: "smart-actions-ai-entry",
            into: directory
        )

        let managedTemplate = SmartAction.samples[0]
        let managedAction = SmartAction(
            id: "snapshot-installed-action",
            actionID: managedTemplate.actionID,
            title: managedTemplate.title,
            subtitle: managedTemplate.subtitle,
            symbol: managedTemplate.symbol,
            tint: managedTemplate.tint,
            stepCount: managedTemplate.stepCount
        )
        try render(
            view: SmartActionsView(actions: [managedAction], initialSelection: .actions),
            store: lightStore,
            name: "smart-actions-management",
            into: directory
        )

        let workflowEditorAction = SmartAction(
            id: "snapshot-workflow-editor",
            actionID: "custom-smart-snapshot",
            title: "开始专注工作",
            subtitle: "4 个步骤 · 打开日历、打开备忘录",
            symbol: "calendar",
            tint: .red,
            stepCount: 4,
            stepActionIDs: ["launch-calendar", "launch-notes", "launch-browser", "volume-down"]
        )
        try render(
            view: SmartActionEditorView(editing: workflowEditorAction) { _ in },
            store: lightStore,
            name: "smart-action-editor",
            into: directory
        )
        let applicationEditorAction = SmartAction(
            id: "snapshot-application-editor",
            actionID: "custom-smart-application-snapshot",
            title: "整理工作环境",
            subtitle: "1 个步骤 · 置于前台：访达",
            symbol: "app.dashed",
            tint: .blue,
            stepCount: 1,
            steps: [
                .applicationControl(
                    bundleIdentifier: "com.apple.finder",
                    name: "访达",
                    operation: .bringToFront
                )
            ],
            triggers: [.device]
        )
        try render(
            view: SmartActionEditorView(
                editing: applicationEditorAction,
                initialSelectedStepIndex: 0
            ) { _ in },
            store: lightStore,
            name: "smart-action-editor-application",
            into: directory
        )
        let invalidURLEditorAction = SmartAction(
            id: "snapshot-invalid-url-editor",
            actionID: "custom-smart-invalid-url-snapshot",
            title: "打开项目页面",
            subtitle: "1 个步骤 · 打开网址",
            symbol: "link",
            tint: .cyan,
            stepCount: 1,
            steps: [.url("https://")],
            triggers: [.device]
        )
        try render(
            view: SmartActionEditorView(
                editing: invalidURLEditorAction,
                initialSelectedStepIndex: 0
            ) { _ in },
            store: lightStore,
            name: "smart-action-editor-invalid-url",
            into: directory
        )
        try render(
            view: SmartActionEditorView(
                editing: workflowEditorAction,
                initialActionMenuOpen: true
            ) { _ in },
            store: lightStore,
            name: "smart-action-editor-add-action",
            into: directory
        )
        try render(
            view: SmartActionEditorView(initialTriggerMenuOpen: true) { _ in },
            store: lightStore,
            name: "smart-action-editor-add-trigger",
            into: directory
        )
        let shortcutTriggerAction = SmartAction(
            id: "snapshot-shortcut-trigger",
            actionID: "custom-smart-shortcut-snapshot",
            title: "快捷键启动工作",
            subtitle: "1 个步骤 · 打开日历",
            symbol: "calendar",
            tint: .red,
            stepCount: 1,
            stepActionIDs: ["launch-calendar"],
            triggers: [
                .device,
                .shortcut(
                    keyCode: 15,
                    flags: UInt64((1 << 17) | (1 << 20)),
                    name: "⇧⌘R"
                )
            ]
        )
        try render(
            view: SmartActionEditorView(
                editing: shortcutTriggerAction,
                initialSelectedTriggerIndex: 1
            ) { _ in },
            store: lightStore,
            name: "smart-action-editor-shortcut-trigger",
            into: directory
        )
        try render(
            view: SmartActionEditorView(
                editing: shortcutTriggerAction,
                reservedShortcutBindings: [
                    GlobalShortcutBinding(
                        actionID: "custom-smart-reserved-shortcut",
                        keyCode: 15,
                        flags: UInt64((1 << 17) | (1 << 20))
                    )
                ],
                initialSelectedTriggerIndex: 1
            ) { _ in },
            store: lightStore,
            name: "smart-action-editor-shortcut-conflict",
            into: directory
        )
        let applicationTriggerAction = SmartAction(
            id: "snapshot-application-trigger",
            actionID: "custom-smart-application-trigger-snapshot",
            title: "进入 Safari 后准备工作",
            subtitle: "1 个步骤 · 打开备忘录",
            symbol: "app.dashed",
            tint: .blue,
            stepCount: 1,
            stepActionIDs: ["launch-notes"],
            triggers: [
                .application(bundleIdentifier: "com.apple.Safari", name: "Safari")
            ]
        )
        try render(
            view: SmartActionEditorView(editing: applicationTriggerAction) { _ in },
            store: lightStore,
            name: "smart-action-editor-application-trigger",
            into: directory
        )

        let emptySmartActionsStore = makeSnapshotStore()
        emptySmartActionsStore.appearanceMode = .light
        emptySmartActionsStore.useDarkAppearance = false
        try render(
            view: SmartActionsView(actions: [], initialSelection: .actions),
            store: emptySmartActionsStore,
            name: "smart-actions-empty",
            into: directory
        )

        lightStore.openDevice(.remote2Pro)
        try render(view: AppShellView(), store: lightStore, name: "device-detail", into: directory)

        lightStore.selectedSlotID = nil
        try render(
            view: AppShellView(),
            store: lightStore,
            name: "device-detail-no-selection",
            into: directory
        )

        lightStore.showApplicationPicker()
        try render(
            view: AppShellView(),
            store: lightStore,
            name: "device-application-picker",
            into: directory
        )
        lightStore.closeApplicationPicker()

        lightStore.selectedSlotID = "ok"
        lightStore.searchText = "不存在的动作"
        try render(
            view: AppShellView(),
            store: lightStore,
            name: "device-detail-no-results",
            into: directory
        )
        lightStore.searchText = ""

        lightStore.assignRecordedKeyboardShortcut(
            keyCode: 40,
            flags: UInt64(NSEvent.ModifierFlags.command.rawValue),
            displayName: "⌘K"
        )
        lightStore.toastMessage = nil
        try render(
            view: AppShellView(),
            store: lightStore,
            name: "keyboard-shortcut-assignment",
            into: directory
        )

        lightStore.selectedSlotID = "left"
        try render(view: AppShellView(), store: lightStore, name: "device-detail-left", into: directory)

        if let leftSlot = RemoteButtonSlot.demoSlots.first(where: { $0.id == "left" }),
           let actionsRingAction = RemoteAction.catalog.first(where: { $0.id == "show-actions-ring" }) {
            lightStore.assign(actionsRingAction, to: leftSlot)
            lightStore.toastMessage = nil
            try render(
                view: AppShellView(),
                store: lightStore,
                name: "device-detail-actions-ring",
                into: directory
            )
        }

        lightStore.selectedTrigger = .hold
        try render(
            view: AppShellView(),
            store: lightStore,
            name: "device-detail-left-hold",
            into: directory
        )
        lightStore.selectedTrigger = .tap

        lightStore.selectedSlotID = "back"
        try render(view: AppShellView(), store: lightStore, name: "device-detail-back", into: directory)
        lightStore.selectedSlotID = "volumeUp"
        try render(view: AppShellView(), store: lightStore, name: "device-detail-volume", into: directory)
        lightStore.selectedSlotID = nil
        try render(
            view: DeviceDetailView(device: .remote2Pro, initialPanel: .device),
            store: lightStore,
            name: "device-information",
            into: directory
        )

        let featureOverviewStore = makeSnapshotStore()
        featureOverviewStore.appearanceMode = .light
        featureOverviewStore.useDarkAppearance = false
        featureOverviewStore.openDevice(.remote2Pro)
        featureOverviewStore.showFeatureOverview()
        try render(
            view: AppShellView(),
            store: featureOverviewStore,
            name: "feature-overview-intro",
            into: directory
        )
        featureOverviewStore.showPhysicalKeyTest()
        featureOverviewStore.backendCoordinator.onInputEvent?(
            RemoteInputEvent(
                deviceID: RemoteDevice.remote2Pro.id,
                slotID: "power",
                phase: .began,
                timestamp: Date()
            )
        )
        featureOverviewStore.backendCoordinator.onInputEvent?(
            RemoteInputEvent(
                deviceID: RemoteDevice.remote2Pro.id,
                slotID: "ok",
                phase: .began,
                timestamp: Date()
            )
        )
        try render(
            view: DeviceFeatureOverviewView(),
            store: featureOverviewStore,
            name: "feature-overview-key-test",
            into: directory
        )
        featureOverviewStore.backendCoordinator.onUnknownUsage?(0xAB, true)
        try render(
            view: DeviceFeatureOverviewView(),
            store: featureOverviewStore,
            name: "feature-overview-key-test-unknown",
            into: directory
        )
        featureOverviewStore.showFeatureOverview()
        for page in 1...7 {
            try render(
                view: DeviceFeatureOverviewView(initialPage: page),
                store: featureOverviewStore,
                name: "feature-overview-page-\(page)",
                into: directory
            )
        }
        let disconnectedDeviceStore = makeSnapshotStore(connected: false)
        disconnectedDeviceStore.permissions = PermissionSnapshot(
            accessibilityGranted: false,
            inputMonitoringGranted: false
        )
        disconnectedDeviceStore.backendLog = "等待 Xiaomi Remote 2 Pro 连接"
        try render(
            view: DeviceDetailView(device: .remote2Pro, initialPanel: .device),
            store: disconnectedDeviceStore,
            name: "device-information-disconnected",
            into: directory
        )
        try render(
            view: DeviceDetailView(device: .remote2Pro, initialPanel: .gestures),
            store: lightStore,
            name: "device-gestures",
            into: directory
        )
        try render(
            view: DeviceDetailView(
                device: .remote2Pro,
                initialPanel: .gestures,
                opensGesturePanel: true
            ),
            store: lightStore,
            name: "device-gesture-settings-panel",
            into: directory
        )
        try render(
            view: DeviceDetailView(device: .remote2Pro, initialPanel: .flow),
            store: lightStore,
            name: "device-flow",
            into: directory
        )
        try render(
            view: DeviceDetailView(
                device: .remote2Pro,
                initialPanel: .flow,
                opensFlowSetup: true
            ),
            store: lightStore,
            name: "device-flow-setup",
            into: directory
        )

        try render(view: SettingsView(), store: lightStore, name: "settings-general", into: directory)
        try render(
            view: SettingsView(initialSelection: .services),
            store: lightStore,
            name: "settings-services",
            into: directory
        )
        try render(
            view: SettingsView(initialSelection: .notifications),
            store: lightStore,
            name: "settings-notifications",
            into: directory
        )
        try render(
            view: SettingsView(initialSelection: .privacy),
            store: lightStore,
            name: "settings-privacy",
            into: directory
        )

        let settingsPermissionRequiredStore = makeSnapshotStore()
        settingsPermissionRequiredStore.appearanceMode = .light
        settingsPermissionRequiredStore.useDarkAppearance = false
        settingsPermissionRequiredStore.permissions = PermissionSnapshot(
            accessibilityGranted: false,
            inputMonitoringGranted: false
        )
        settingsPermissionRequiredStore.backendLog = "已检测到遥控器；授予输入监控权限后即可读取按键"
        try render(
            view: SettingsView(initialSelection: .privacy),
            store: settingsPermissionRequiredStore,
            name: "settings-privacy-required",
            into: directory
        )

        let darkStore = makeSnapshotStore()
        darkStore.appearanceMode = .dark
        darkStore.useDarkAppearance = true
        try render(view: AppShellView(), store: darkStore, name: "home-dark", into: directory)

        let disconnectedDarkHomeStore = makeSnapshotStore(connected: false)
        disconnectedDarkHomeStore.appearanceMode = .dark
        disconnectedDarkHomeStore.useDarkAppearance = true
        try render(
            view: AppShellView(),
            store: disconnectedDarkHomeStore,
            name: "home-disconnected-dark",
            into: directory
        )
        darkStore.selectSection(.automations)
        try render(view: AppShellView(), store: darkStore, name: "smart-actions-dark", into: directory)

        let emptySmartActionsDarkStore = makeSnapshotStore()
        emptySmartActionsDarkStore.appearanceMode = .dark
        emptySmartActionsDarkStore.useDarkAppearance = true
        try render(
            view: SmartActionsView(actions: [], initialSelection: .actions),
            store: emptySmartActionsDarkStore,
            name: "smart-actions-empty-dark",
            into: directory
        )

        darkStore.openDevice(.remote2Pro)
        try render(view: AppShellView(), store: darkStore, name: "device-detail-dark", into: directory)
        darkStore.selectedSlotID = nil
        try render(
            view: DeviceDetailView(device: .remote2Pro, initialPanel: .gestures),
            store: darkStore,
            name: "device-gestures-dark",
            into: directory
        )
        try render(
            view: DeviceDetailView(device: .remote2Pro, initialPanel: .flow),
            store: darkStore,
            name: "device-flow-dark",
            into: directory
        )
        try render(
            view: DeviceDetailView(
                device: .remote2Pro,
                initialPanel: .flow,
                opensFlowSetup: true
            ),
            store: darkStore,
            name: "device-flow-setup-dark",
            into: directory
        )
        try render(
            view: DeviceDetailView(device: .remote2Pro, initialPanel: .device),
            store: darkStore,
            name: "device-information-dark",
            into: directory
        )
        darkStore.selectedSlotID = "ok"
        darkStore.searchText = "不存在的动作"
        try render(
            view: AppShellView(),
            store: darkStore,
            name: "device-detail-no-results-dark",
            into: directory
        )
        darkStore.searchText = ""
        try render(view: SettingsView(), store: darkStore, name: "settings-general-dark", into: directory)
    }

    @MainActor
    private func makeSnapshotStore(connected: Bool = true) -> AppStore {
        let configurationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-UISnapshots-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("config.json")
        let snapshot = connected
            ? BluetoothDeviceSnapshot(batteryLevel: 100, firmwareVersion: "2671")
            : nil
        let store = AppStore(
            configurationStore: LocalConfigurationStore(fileURL: configurationURL),
            runtimeServicesEnabled: false,
            initialDeviceSnapshot: snapshot
        )
        store.permissions = PermissionSnapshot(
            accessibilityGranted: true,
            inputMonitoringGranted: true
        )
        store.backendLog = connected
            ? "HID 监听器已启动，等待 Xiaomi Remote 2 Pro"
            : "等待 Xiaomi Remote 2 Pro 连接"
        return store
    }

    @MainActor
    private func render<Content: View>(
        view: Content,
        store: AppStore,
        name: String,
        into directory: URL
    ) throws {
        // Match the production content view exactly. The installed 1,180 × 760
        // window includes a 32-point hidden-title-bar region above this view.
        let size = CGSize(width: 1_180, height: 728)
        let hostingView = NSHostingView(
            rootView: view
                .environmentObject(store)
                .frame(width: size.width, height: size.height)
                .preferredColorScheme(store.preferredColorScheme ?? .light)
        )
        hostingView.frame = CGRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        hostingView.displayIfNeeded()

        guard let representation = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            XCTFail("无法创建 \(name) UI 快照")
            return
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: representation)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            XCTFail("无法编码 \(name) UI 快照")
            return
        }
        try data.write(to: directory.appendingPathComponent("\(name).png"))
    }
}
