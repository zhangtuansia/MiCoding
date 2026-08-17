import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppStore: ObservableObject {
    static let languageSettingsURLs = [
        "x-apple.systempreferences:com.apple.Localization-Settings.extension",
        "x-apple.systempreferences:com.apple.Localization"
    ]
    static let displaysSettingsURLs = [
        "x-apple.systempreferences:com.apple.Displays-Settings.extension",
        "x-apple.systempreferences:com.apple.preference.displays"
    ]
    static let handoffSettingsURLs = [
        "x-apple.systempreferences:com.apple.AirDrop-Handoff-Settings.extension",
        "x-apple.systempreferences:com.apple.Network-Settings.extension?AirDrop"
    ]

    @Published var activeSection: AppSection = .devices
    @Published var activeDeviceID: String?
    @Published var showsConnectionTypePicker = false
    @Published var showsLocalProfile = false
    @Published var showsAIPromptNotice = false
    @Published var showsExploreCenter = false
    @Published var showsFeatureOverview = false
    @Published private(set) var featureOverviewStartsInKeyTest = false
    @Published var showsApplicationPicker = false
    @Published var showsActionsRing = false
    @Published var editsActionsRing = false
    @Published var actionsRingSettingsSelected = false
    @Published var selectedActionsRingIndex: Int? = 0
    @Published private(set) var actionsRingActionIDs = AppStore.defaultActionsRingActionIDs
    @Published private(set) var actionsRingAssignmentsByProfile = [
        "global": AppStore.defaultActionsRingActionIDs
    ]
    @Published private(set) var selectedActionsRingProfileID = "global"
    @Published private(set) var actionsRingSize: ActionsRingSize = .medium
    @Published var selectedSlotID: String?
    @Published var selectedTrigger: RemoteTrigger = .tap
    @Published var selectedProfileID = AppProfile.profiles[0].id
    @Published var selectedCategory: ActionCategory?
    @Published var searchText = ""
    @Published var connectionState: DeviceConnectionState = .disconnected
    @Published private(set) var devicePresent = false
    @Published private(set) var batteryLevel: Int?
    @Published private(set) var firmwareVersion: String?
    @Published private(set) var inputBackendReady = false
    @Published var pressedSlotID: String?
    @Published private(set) var detectedPhysicalKeyIDs: Set<String> = []
    @Published private(set) var unknownPhysicalUsages: Set<UInt32> = []
    @Published private(set) var lastUnknownPhysicalUsageDate: Date?
    @Published var draggedActionID: String?
    @Published var toastMessage: String?
    @Published var useDarkAppearance = false
    @Published var appearanceMode: AppAppearanceMode = .system
    @Published var automaticUpdatesEnabled = true
    @Published private(set) var softwareUpdateStatus: SoftwareUpdateStatus = .idle
    @Published private(set) var remoteIsManaged = true
    @Published var inputServiceEnabled = true
    @Published var showActionNotifications = true
    @Published var showPermissionReminders = true
    @Published var showExperienceRecommendations = true
    @Published var showConnectionNotifications = true
    @Published var showLowBatteryNotifications = true
    @Published var permissions = PermissionService.current()
    @Published var backendLog = "后端尚未启动"
    @Published private(set) var holdMilliseconds = BackendSettings().holdMilliseconds
    @Published private(set) var doubleTapMilliseconds = BackendSettings().doubleTapMilliseconds
    @Published private(set) var debounceMilliseconds = BackendSettings().debounceMilliseconds ?? 30
    @Published private(set) var profiles = AppProfile.profiles
    @Published private(set) var availableApplicationProfiles: [AppProfile] = []
    @Published private(set) var requestedAutomationCategory: String?
    @Published private(set) var configurationLoadWarning: String?
    // Templates live in SmartAction.samples. This collection mirrors the
    // original Smart Actions “管理” tab and therefore only contains actions
    // the user has added, created, or imported.
    @Published private(set) var smartActions: [SmartAction] = []

    private var lastContentSection: AppSection = .devices
    private var featureOverviewReturnsToExploreCenter = false
    private var actionsRingReturnsToExploreCenter = false

    private let configurationStore: LocalConfigurationStore
    private let providedBackendCoordinator: BackendCoordinator?
    private var backendSettings = BackendSettings()
    private var holdAssignmentsByProfile: [String: [String: String]] = [:]
    private var doubleTapAssignmentsByProfile: [String: [String: String]] = [:]
    private var pendingAssignmentActionID: String?
    private var removedProfileIDs: Set<String> = []
    private var batteryRefreshTask: Task<Void, Never>?
    private var updateCheckTask: Task<Void, Never>?
    private var hasScheduledAutomaticUpdateCheck = false
    private var lastBatteryRefreshDate: Date?
    private var lowBatteryWarningIssued = false
    private var remoteVoiceReportCount = 0
    private var hasPresentedConfigurationLoadWarning = false
    private var configurationPersistenceBlocked = false
    private var hasPresentedConfigurationSaveWarning = false
    private let runtimeServicesEnabled: Bool
    private let actionsRingOverlayController = ActionsRingOverlayController()

    private struct ShortcutSignature: Hashable {
        let keyCode: UInt16
        let flags: UInt64
    }

    static let defaultActionsRingActionIDs = [
        "play-pause",
        "launch-notes",
        "explore-ai",
        "lock",
        "launch-micoding",
        "screenshot",
        "emoji-picker",
        "launch-finder"
    ]

    private static let legacyDefaultActionsRingActionIDs = [
        "play-pause",
        "launch-notes",
        "spotlight",
        "lock",
        "launch-browser",
        "screenshot",
        "mission-control",
        "launch-finder"
    ]

    lazy var backendCoordinator: BackendCoordinator = {
        let coordinator = providedBackendCoordinator ?? BackendCoordinator()
        coordinator.configure(settings: backendSettings)
        coordinator.resolveActionID = { [weak self] bundleIdentifier, slotID, trigger in
            guard let self, !self.showsFeatureOverview else { return nil }
            return self.executionActionID(
                bundleIdentifier: bundleIdentifier,
                slotID: slotID,
                trigger: trigger
            )
        }
        coordinator.resolveCommand = { [weak self] actionID in
            self?.command(for: actionID)
        }
        coordinator.onInputEvent = { [weak self] event in
            guard let self, self.remoteIsManaged else { return }
            handlePhysicalInput(event)
            devicePresent = true
            inputBackendReady = true
            connectionState = .connected
            backendLog = "收到 \(event.slotID) \(event.phase == .began ? "按下" : "松开")"
            refreshBatteryLevel()
        }
        coordinator.onUnknownUsage = { [weak self] usage, isDown in
            guard let self, self.remoteIsManaged else { return }
            self.backendLog = String(
                format: "检测到未知 HID usage 0x%02X (%@)",
                usage,
                isDown ? "down" : "up"
            )
            guard self.showsFeatureOverview, isDown else { return }
            self.unknownPhysicalUsages.insert(usage)
            self.lastUnknownPhysicalUsageDate = Date()
        }
        coordinator.onVoiceReport = { [weak self] report in
            guard let self, remoteIsManaged else { return }
            remoteVoiceReportCount += 1
            if remoteVoiceReportCount == 1 || remoteVoiceReportCount.isMultiple(of: 50) {
                backendLog = "收到遥控器麦克风数据 · 报告 \(report.reportID) · \(report.bytes.count) 字节"
            }
        }
        coordinator.onConnectionChanged = { [weak self] connected in
            guard let self, self.remoteIsManaged else { return }
            let previousState = self.connectionState
            self.inputBackendReady = connected
            if connected {
                self.devicePresent = true
                self.connectionState = .connected
                self.refreshBatteryLevel()
            } else {
                self.refreshDevicePresence()
            }
            if previousState != self.connectionState {
                self.showConnectionToast(
                    self.connectionState == .connected ? "遥控器已连接" : "遥控器连接已断开"
                )
            }
        }
        coordinator.onLog = { [weak self] message in
            self?.backendLog = message
        }
        return coordinator
    }()

    private(set) var assignmentsByProfile: [String: [String: String]] = [
        "global": [
            "power": "lock",
            "voice": "spotlight",
            "up": "arrow-up",
            "down": "arrow-down",
            "left": "arrow-left",
            "right": "arrow-right",
            "ok": "play-pause",
            "back": "browser-back",
            "home": "desktop",
            "volumeUp": "volume-up",
            "volumeDown": "volume-down",
            "tv": "launch-browser",
            "menu": "screenshot"
        ]
    ]

    init(
        configurationStore: LocalConfigurationStore = LocalConfigurationStore(),
        runtimeServicesEnabled: Bool = true,
        initialDeviceSnapshot: BluetoothDeviceSnapshot? = nil,
        backendCoordinator: BackendCoordinator? = nil
    ) {
        self.configurationStore = configurationStore
        self.runtimeServicesEnabled = runtimeServicesEnabled
        self.providedBackendCoordinator = backendCoordinator
        var shouldPersistNormalizedSmartActions = false
        do {
            if let saved = try configurationStore.load() {
                assignmentsByProfile = saved.assignmentsByProfile
                migrateLegacyAssignments()
                holdAssignmentsByProfile = saved.holdAssignmentsByProfile
                doubleTapAssignmentsByProfile = saved.doubleTapAssignmentsByProfile
                backendSettings = saved.settings
                holdMilliseconds = saved.settings.holdMilliseconds
                doubleTapMilliseconds = saved.settings.doubleTapMilliseconds
                debounceMilliseconds = saved.settings.debounceMilliseconds ?? 30
                restoreCustomProfiles()
                appearanceMode = saved.appearanceMode ?? (saved.useDarkAppearance ? .dark : .system)
                useDarkAppearance = appearanceMode == .dark
                automaticUpdatesEnabled = saved.automaticUpdatesEnabled ?? true
                remoteIsManaged = saved.remoteIsManaged ?? true
                inputServiceEnabled = saved.inputServiceEnabled ?? true
                showActionNotifications = saved.showActionNotifications ?? true
                showPermissionReminders = saved.showPermissionReminders ?? true
                showExperienceRecommendations = saved.showExperienceRecommendations ?? true
                showConnectionNotifications = saved.showConnectionNotifications ?? true
                showLowBatteryNotifications = saved.showLowBatteryNotifications ?? true
                let savedRingActions = migratedActionsRingActionIDs(saved.actionsRingActionIDs ?? [])
                let savedRingAssignments = (saved.actionsRingAssignmentsByProfile ?? [:])
                    .filter { $0.value.count == 8 }
                    .mapValues(migratedActionsRingActionIDs)
                if !savedRingAssignments.isEmpty {
                    actionsRingAssignmentsByProfile = savedRingAssignments
                } else if savedRingActions.count == 8 {
                    actionsRingAssignmentsByProfile = ["global": savedRingActions]
                }
                if actionsRingAssignmentsByProfile["global"] == nil {
                    actionsRingAssignmentsByProfile["global"] = AppStore.defaultActionsRingActionIDs
                }
                actionsRingSize = saved.actionsRingSize ?? .medium
                removedProfileIDs = Set(saved.removedProfileIDs ?? [])
                profiles.removeAll { profile in
                    profile.id != "global" && removedProfileIDs.contains(profile.id)
                }
                selectedProfileID = profiles.contains(where: { $0.id == saved.lastProfileID })
                    ? saved.lastProfileID
                    : "global"
                let savedActionsRingProfileID = saved.lastActionsRingProfileID ?? "global"
                selectedActionsRingProfileID = profiles.contains(where: { $0.id == savedActionsRingProfileID })
                    ? savedActionsRingProfileID
                    : "global"
                actionsRingActionIDs = actionsRingAssignmentsByProfile[selectedActionsRingProfileID]
                    ?? actionsRingAssignmentsByProfile["global"]
                    ?? AppStore.defaultActionsRingActionIDs
                shouldPersistNormalizedSmartActions = restoreSmartActions(saved.customSmartActions ?? [])
            }
        } catch {
            let recoveryURL = try? configurationStore.makeRecoveryCopy()
            configurationPersistenceBlocked = recoveryURL == nil
            let recoveryDetail = recoveryURL.map {
                "原文件已保留为 \($0.lastPathComponent)"
            } ?? "为避免覆盖原文件，本次运行不会保存配置"
            configurationLoadWarning = "无法读取现有配置；\(recoveryDetail)"
            backendLog = "读取本地配置失败：\(error.localizedDescription)"
        }
        if let initialDeviceSnapshot {
            devicePresent = true
            connectionState = .connected
            batteryLevel = initialDeviceSnapshot.batteryLevel
            firmwareVersion = initialDeviceSnapshot.firmwareVersion
        }
        if shouldPersistNormalizedSmartActions {
            persistConfiguration()
        }
    }

    private func migrateLegacyAssignments() {
        for profileID in Array(assignmentsByProfile.keys) {
            guard var assignments = assignmentsByProfile[profileID],
                  assignments["voice"] == nil,
                  let legacyAction = assignments.removeValue(forKey: "assistant") else { continue }
            assignments["voice"] = legacyAction
            assignmentsByProfile[profileID] = assignments
        }

        // Releases before directional actions existed shipped the otherwise
        // complete default map with all four D-pad entries absent. Recognize
        // that exact legacy shape and fill the missing native arrow behavior.
        // A deliberately cleared/custom map does not satisfy this signature,
        // so reset configurations remain empty.
        guard var globalAssignments = assignmentsByProfile["global"],
              globalAssignments["power"] == "lock",
              globalAssignments["voice"] == "spotlight",
              globalAssignments["ok"] == "play-pause",
              globalAssignments["back"] == "browser-back",
              ["up", "down", "left", "right"].allSatisfy({ globalAssignments[$0] == nil }) else {
            return
        }
        globalAssignments["up"] = "arrow-up"
        globalAssignments["down"] = "arrow-down"
        globalAssignments["left"] = "arrow-left"
        globalAssignments["right"] = "arrow-right"
        assignmentsByProfile["global"] = globalAssignments
    }

    var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var deviceConnectionDetail: String {
        guard devicePresent else { return "未连接" }
        guard permissions.inputMonitoringGranted else {
            return "已连接，等待输入监控权限"
        }
        return inputBackendReady ? "已连接并监听按键" : "已连接，正在启动 HID 监听"
    }

    var activeProfile: AppProfile {
        profiles.first(where: { $0.id == selectedProfileID }) ?? profiles[0]
    }

    var installedSmartActionCatalog: [RemoteAction] {
        smartActions.reduce(into: []) { result, action in
            guard !result.contains(where: { $0.id == action.actionID }) else { return }
            result.append(action.remoteAction)
        }
    }

    var actionsRingSmartActionCatalog: [RemoteAction] {
        smartActions.reduce(into: []) { result, action in
            guard action.isEnabled,
                  action.triggers?.contains(.actionsRing) == true,
                  !result.contains(where: { $0.id == action.actionID }) else { return }
            result.append(action.remoteAction)
        }
    }

    var runningApplicationCandidates: [AppProfile] {
        let existingBundleIdentifiers = Set(profiles.compactMap(\.bundleIdentifier))
        return NSWorkspace.shared.runningApplications
            .filter { application in
                application.activationPolicy == .regular
                    && application.bundleIdentifier != Bundle.main.bundleIdentifier
                    && application.bundleIdentifier.map { !existingBundleIdentifiers.contains($0) } == true
            }
            .compactMap { application -> AppProfile? in
                guard let bundleIdentifier = application.bundleIdentifier else { return nil }
                return AppProfile(
                    id: bundleIdentifier,
                    title: application.localizedName ?? bundleIdentifier,
                    subtitle: "应用专属配置",
                    symbol: "app.dashed",
                    tint: .gray,
                    bundleIdentifier: bundleIdentifier
                )
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var selectedSlot: RemoteButtonSlot? {
        guard let selectedSlotID else { return nil }
        return RemoteButtonSlot.demoSlots.first(where: { $0.id == selectedSlotID })
    }

    var draggedAction: RemoteAction? {
        guard let draggedActionID else { return nil }
        return resolvedAction(id: draggedActionID)
    }

    var configuredSlotCount: Int {
        RemoteButtonSlot.demoSlots.reduce(into: 0) { count, slot in
            if action(for: slot.id) != nil { count += 1 }
        }
    }

    var actionsRingActions: [RemoteAction?] {
        actionsRingActionIDs.map { actionID in
            actionID.isEmpty ? nil : eligibleAction(id: actionID, for: .actionsRing)
        }
    }

    var selectedActionsRingProfile: AppProfile {
        profiles.first(where: { $0.id == selectedActionsRingProfileID })
            ?? profiles.first(where: { $0.id == "global" })
            ?? AppProfile.profiles[0]
    }

    var configurationProgressText: String {
        "已配置 \(configuredSlotCount) / \(RemoteButtonSlot.demoSlots.count) 个按键"
    }

    func action(for slotID: String, trigger: RemoteTrigger = .tap) -> RemoteAction? {
        let table: [String: [String: String]]
        switch trigger {
        case .tap:
            table = assignmentsByProfile
        case .hold:
            table = holdAssignmentsByProfile
        case .doubleTap:
            table = doubleTapAssignmentsByProfile
        }
        let actionID = table[selectedProfileID]?[slotID]
            ?? table["global"]?[slotID]
        guard let slot = RemoteButtonSlot.demoSlots.first(where: { $0.id == slotID }),
              let actionID,
              let action = resolvedAction(id: actionID),
              slot.accepts(action, trigger: trigger) else { return nil }
        return action
    }

    func openDevice(_ device: RemoteDevice) {
        guard remoteIsManaged else {
            beginAddingDevice()
            return
        }
        showsLocalProfile = false
        showsAIPromptNotice = false
        showsExploreCenter = false
        actionsRingReturnsToExploreCenter = false
        closeActionsRing()
        showsConnectionTypePicker = false
        activeDeviceID = device.id
        selectedSlotID = nil
        selectedTrigger = .tap
        showsApplicationPicker = false
        activeSection = .devices
    }

    func closeActionLibrary() {
        selectedSlotID = nil
        selectedTrigger = .tap
        searchText = ""
        selectedCategory = nil
    }

    func showApplicationPicker() {
        selectedSlotID = nil
        selectedTrigger = .tap
        searchText = ""
        selectedCategory = nil
        refreshAvailableApplicationProfiles()
        showsApplicationPicker = true
    }

    func closeApplicationPicker() {
        showsApplicationPicker = false
    }

    func selectSlot(_ slot: RemoteButtonSlot) {
        guard selectedSlotID != slot.id else { return }
        showsApplicationPicker = false
        let actionLibraryWasOpen = selectedSlotID != nil
        selectedSlotID = slot.id
        if !actionLibraryWasOpen {
            selectedTrigger = .tap
        }
        searchText = ""
        selectedCategory = nil

        if let actionID = pendingAssignmentActionID,
           let action = resolvedAction(id: actionID) {
            pendingAssignmentActionID = nil
            assign(action, to: slot)
        }
    }

    func closeDevice() {
        activeDeviceID = nil
        selectedSlotID = nil
        draggedActionID = nil
        selectedTrigger = .tap
        showsApplicationPicker = false
        pendingAssignmentActionID = nil
    }

    func beginAddingDevice() {
        showsLocalProfile = false
        showsAIPromptNotice = false
        showsExploreCenter = false
        actionsRingReturnsToExploreCenter = false
        closeActionsRing()
        closeDevice()
        activeSection = .devices
        showsConnectionTypePicker = true
    }

    func cancelAddingDevice() {
        showsConnectionTypePicker = false
    }

    func connectWithBluetooth() {
        // Options+ keeps this chooser visible and delegates Bluetooth pairing
        // directly to macOS instead of inserting another in-app wizard page.
        if runtimeServicesEnabled {
            openBluetoothSettings()
        }
        refreshRuntimeState()
    }

    func finishAddingDevice() {
        showsConnectionTypePicker = false
        activeSection = .devices
        remoteIsManaged = true
        persistConfiguration()
        if inputServiceEnabled {
            restartBackend()
        } else {
            refreshRuntimeState()
        }
    }

    func removeManagedDevice(openBluetoothSettings shouldOpenBluetoothSettings: Bool = true) {
        guard remoteIsManaged else { return }
        remoteIsManaged = false
        backendCoordinator.stop()
        inputBackendReady = false
        devicePresent = false
        connectionState = .disconnected
        batteryLevel = nil
        firmwareVersion = nil
        lowBatteryWarningIssued = false
        lastBatteryRefreshDate = nil
        batteryRefreshTask?.cancel()
        batteryRefreshTask = nil
        closeDevice()
        showsConnectionTypePicker = false
        activeSection = .devices
        persistConfiguration()
        if shouldOpenBluetoothSettings {
            openBluetoothSettings()
        }
        showToast("设备已从 MiCoding 移除；按键配置已保留")
    }

    func beginAssigningSmartAction(_ smartAction: SmartAction) {
        guard command(for: smartAction.actionID) != nil else {
            showToast("“\(smartAction.title)”当前无法分配给按键")
            return
        }
        openDevice(.remote2Pro)
        pendingAssignmentActionID = smartAction.actionID
        showToast("请选择要运行“\(smartAction.title)”的遥控器按键")
    }

    func selectSection(_ section: AppSection) {
        showsLocalProfile = false
        showsAIPromptNotice = false
        showsExploreCenter = false
        actionsRingReturnsToExploreCenter = false
        closeActionsRing()
        showsConnectionTypePicker = false
        closeDevice()
        if section == .settings, activeSection != .settings {
            lastContentSection = activeSection
        } else if section != .settings {
            lastContentSection = section
        }
        if section == .automations {
            requestedAutomationCategory = nil
        }
        activeSection = section
    }

    func showAIWorkflowTemplates() {
        selectSection(.automations)
        requestedAutomationCategory = "AI"
    }

    func consumeRequestedAutomationCategory() -> String? {
        defer { requestedAutomationCategory = nil }
        return requestedAutomationCategory
    }

    func showLocalProfile() {
        guard activeSection == .devices,
              activeDeviceID == nil,
              !showsExploreCenter,
              !showsActionsRing,
              !showsConnectionTypePicker else { return }
        showsAIPromptNotice = false
        showsLocalProfile = true
    }

    func showExploreCenter() {
        guard activeSection == .devices,
              activeDeviceID == nil,
              !showsActionsRing,
              !showsConnectionTypePicker else { return }
        showsLocalProfile = false
        showsAIPromptNotice = false
        showsExploreCenter = true
    }

    func dismissExploreCenter() {
        showsExploreCenter = false
    }

    func showFeatureOverview() {
        presentFeatureOverview(startsInKeyTest: false)
    }

    func showPhysicalKeyTest() {
        presentFeatureOverview(startsInKeyTest: true)
    }

    private func presentFeatureOverview(startsInKeyTest: Bool) {
        featureOverviewReturnsToExploreCenter = showsExploreCenter
        showsExploreCenter = false
        closeActionLibrary()
        detectedPhysicalKeyIDs.removeAll()
        unknownPhysicalUsages.removeAll()
        lastUnknownPhysicalUsageDate = nil
        pressedSlotID = nil
        featureOverviewStartsInKeyTest = startsInKeyTest
        showsFeatureOverview = true
    }

    func dismissFeatureOverview() {
        showsFeatureOverview = false
        featureOverviewStartsInKeyTest = false
        pressedSlotID = nil
        closeActionLibrary()
        if featureOverviewReturnsToExploreCenter {
            showsExploreCenter = true
        }
        featureOverviewReturnsToExploreCenter = false
    }

    func dismissLocalProfile() {
        showsLocalProfile = false
    }

    func toggleAIPromptNotice() {
        guard activeSection == .devices,
              activeDeviceID == nil,
              !showsExploreCenter,
              !showsActionsRing,
              !showsConnectionTypePicker else { return }
        showsLocalProfile = false
        showsAIPromptNotice.toggle()
    }

    func dismissAIPromptNotice() {
        showsAIPromptNotice = false
    }

    func showActionsRing() {
        guard activeSection == .devices,
              activeDeviceID == nil,
              !showsExploreCenter,
              !showsConnectionTypePicker else { return }
        showsLocalProfile = false
        showsAIPromptNotice = false
        actionsRingReturnsToExploreCenter = false
        showsActionsRing = true
        editsActionsRing = false
        actionsRingSettingsSelected = false
        selectedActionsRingIndex = 0
    }

    func showActionsRingFromExploreCenter() {
        guard showsExploreCenter else { return }
        showsExploreCenter = false
        showActionsRing()
        actionsRingReturnsToExploreCenter = showsActionsRing
    }

    func showActionsRingFromDeviceDetail() {
        guard activeSection == .devices,
              activeDeviceID != nil,
              !showsExploreCenter,
              !showsConnectionTypePicker else { return }
        showsApplicationPicker = false
        selectedSlotID = nil
        showsActionsRing = true
        editsActionsRing = false
        actionsRingSettingsSelected = false
        selectedActionsRingIndex = 0
        actionsRingReturnsToExploreCenter = false
    }

    func closeActionsRing() {
        showsActionsRing = false
        editsActionsRing = false
        actionsRingSettingsSelected = false
        selectedActionsRingIndex = 0
        if actionsRingReturnsToExploreCenter {
            showsExploreCenter = true
        }
        actionsRingReturnsToExploreCenter = false
    }

    func editActionsRing() {
        guard showsActionsRing else { return }
        editsActionsRing = true
        actionsRingSettingsSelected = false
        selectedActionsRingIndex = nil
    }

    func leaveActionsRingEditor() {
        editsActionsRing = false
    }

    func navigateBackFromActionsRing() {
        if editsActionsRing {
            leaveActionsRingEditor()
        } else {
            closeActionsRing()
        }
    }

    func selectActionsRingSettings(_ selected: Bool) {
        guard showsActionsRing, !editsActionsRing else { return }
        actionsRingSettingsSelected = selected
    }

    func selectActionsRingSlot(_ index: Int) {
        guard actionsRingActionIDs.indices.contains(index) else { return }
        selectedActionsRingIndex = index
    }

    func selectActionsRingProfile(_ profile: AppProfile) {
        guard profiles.contains(where: { $0.id == profile.id }) else { return }
        actionsRingAssignmentsByProfile[selectedActionsRingProfileID] = actionsRingActionIDs
        selectedActionsRingProfileID = profile.id
        actionsRingActionIDs = actionsRingAssignmentsByProfile[profile.id]
            ?? actionsRingAssignmentsByProfile["global"]
            ?? AppStore.defaultActionsRingActionIDs
        selectedActionsRingIndex = nil
        persistConfiguration()
    }

    func addActionsRingProfile(_ profile: AppProfile) {
        addApplicationProfile(profile)
        selectActionsRingProfile(profile)
    }

    func assignActionToActionsRing(_ action: RemoteAction) {
        guard let index = selectedActionsRingIndex,
              actionsRingActionIDs.indices.contains(index) else {
            showToast("请先选择动作环上的一个位置")
            return
        }
        guard eligibleAction(id: action.id, for: .actionsRing) != nil else {
            showToast("“\(action.title)”不能添加到 Actions Ring")
            return
        }
        actionsRingActionIDs[index] = action.id
        actionsRingAssignmentsByProfile[selectedActionsRingProfileID] = actionsRingActionIDs
        persistConfiguration()
        showToast("已将“\(action.title)”添加到 Actions Ring")
    }

    @discardableResult
    func assignActionToActionsRing(actionID: String, at index: Int) -> Bool {
        guard actionsRingActionIDs.indices.contains(index),
              let action = eligibleAction(id: actionID, for: .actionsRing) else { return false }
        selectedActionsRingIndex = index
        assignActionToActionsRing(action)
        return true
    }

    func clearSelectedActionsRingSlot() {
        guard let index = selectedActionsRingIndex,
              actionsRingActionIDs.indices.contains(index) else { return }
        actionsRingActionIDs[index] = ""
        actionsRingAssignmentsByProfile[selectedActionsRingProfileID] = actionsRingActionIDs
        persistConfiguration()
    }

    func actionsRingAction(at index: Int, for bundleIdentifier: String?) -> RemoteAction? {
        let actionIDs = actionsRingActionIDs(for: bundleIdentifier)
        guard actionIDs.indices.contains(index) else { return nil }
        return eligibleAction(id: actionIDs[index], for: .actionsRing)
    }

    /// Runs the action currently visible in the editor's selected profile.
    func runActionsRingAction(at index: Int) {
        guard actionsRingActionIDs.indices.contains(index),
              let action = eligibleAction(
                id: actionsRingActionIDs[index],
                for: .actionsRing
              ) else { return }
        runAction(actionID: action.id, title: action.title)
    }

    /// Runs the action that was rendered for a concrete frontmost application.
    func runActionsRingAction(at index: Int, for bundleIdentifier: String?) {
        guard let action = actionsRingAction(at: index, for: bundleIdentifier) else { return }
        runAction(actionID: action.id, title: action.title)
    }

    func showRuntimeActionsRing() {
        // Capture the active application once for both rendering and execution.
        // The editor can be showing a different profile, so reading the mutable
        // `actionsRingActionIDs` array after the overlay appears can otherwise
        // execute a different action than the one the user selected.
        let bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let actionIDs = actionsRingActionIDs(for: bundleIdentifier)
        let actions = actionIDs.map { actionID in
            actionID.isEmpty ? nil : eligibleAction(id: actionID, for: .actionsRing)
        }
        guard actions.contains(where: { $0 != nil }) else {
            showToast("请先为 Actions Ring 添加操作")
            return
        }
        actionsRingOverlayController.show(
            actions: actions,
            size: actionsRingSize,
            onSelect: { [weak self] action in
                guard let self else { return }
                guard self.eligibleAction(id: action.id, for: .actionsRing) != nil else {
                    self.dismissRuntimeActionsRing()
                    self.showToast("此操作已停用或不再用于 Actions Ring")
                    return
                }
                self.runAction(actionID: action.id, title: action.title)
            },
            onAdjust: { [weak self] action, delta in
                self?.adjustActionsRingParameter(action, by: delta)
            }
        )
        backendLog = "已在指针位置打开 Actions Ring"
    }

    func adjustActionsRingParameter(_ action: RemoteAction, by delta: Int) {
        guard delta != 0, let parameter = action.actionsRingParameterKind else { return }
        let actionID: String
        switch (parameter, delta > 0) {
        case (.volume, true): actionID = "volume-up"
        case (.volume, false): actionID = "volume-down"
        case (.brightness, true): actionID = "brightness-up"
        case (.brightness, false): actionID = "brightness-down"
        }

        let count = min(abs(delta), 8)
        Task { @MainActor [weak self] in
            guard let self else { return }
            let commands = Array(repeating: self.command(for: actionID) ?? .none, count: count)
            let result = await self.backendCoordinator.execute(
                command: .sequence(commands),
                source: "Actions Ring 参数调节"
            )
            switch result {
            case .success:
                self.backendLog = "Actions Ring 已调节\(parameter.title)"
            case let .failure(message):
                self.showImportantToast("调节失败：\(message)")
            }
        }
    }

    func actionsRingActionIDs(for bundleIdentifier: String?) -> [String] {
        let profileID = bundleIdentifier.flatMap { candidate in
            profiles.first(where: { $0.bundleIdentifier == candidate })?.id
        }
        return profileID.flatMap { actionsRingAssignmentsByProfile[$0] }
            ?? actionsRingAssignmentsByProfile["global"]
            ?? AppStore.defaultActionsRingActionIDs
    }

    func dismissRuntimeActionsRing() {
        actionsRingOverlayController.dismiss()
    }

    func setActionsRingSize(_ size: ActionsRingSize) {
        guard actionsRingSize != size else { return }
        actionsRingSize = size
        persistConfiguration()
    }

    func leaveSettings() {
        showsConnectionTypePicker = false
        closeDevice()
        activeSection = lastContentSection
    }

    func assign(
        _ action: RemoteAction,
        to slot: RemoteButtonSlot,
        announce: Bool = true
    ) {
        guard slot.accepts(action, trigger: selectedTrigger) else {
            draggedActionID = nil
            showToast("“\(action.title)”不能分配到\(slot.name)键")
            return
        }

        var table: [String: [String: String]]
        switch selectedTrigger {
        case .tap:
            table = assignmentsByProfile
        case .hold:
            table = holdAssignmentsByProfile
        case .doubleTap:
            table = doubleTapAssignmentsByProfile
        }

        var profileAssignments = table[selectedProfileID] ?? [:]
        profileAssignments[slot.id] = action.id
        table[selectedProfileID] = profileAssignments
        switch selectedTrigger {
        case .tap:
            assignmentsByProfile = table
        case .hold:
            holdAssignmentsByProfile = table
        case .doubleTap:
            doubleTapAssignmentsByProfile = table
        }
        selectedSlotID = slot.id
        draggedActionID = nil
        objectWillChange.send()
        persistConfiguration()
        if announce {
            showToast("已将“\(action.title)”分配到\(slot.name)键 · \(selectedTrigger.title)")
        }
    }

    func clearSelectedAssignment() {
        guard let selectedSlot else { return }

        switch selectedTrigger {
        case .tap:
            assignmentsByProfile[selectedProfileID]?[selectedSlot.id] = nil
        case .hold:
            holdAssignmentsByProfile[selectedProfileID]?[selectedSlot.id] = nil
        case .doubleTap:
            doubleTapAssignmentsByProfile[selectedProfileID]?[selectedSlot.id] = nil
        }
        objectWillChange.send()
        persistConfiguration()
        showToast("已清除\(selectedSlot.name)键 · \(selectedTrigger.title)")
    }

    func assignToSelectedSlot(_ action: RemoteAction) {
        guard let selectedSlot else {
            showToast("请先在遥控器上选择一个按键")
            return
        }
        assign(action, to: selectedSlot)
    }

    @discardableResult
    func assignRecordedKeyboardShortcut(
        keyCode: UInt16,
        flags: UInt64,
        displayName: String
    ) -> RemoteAction? {
        guard let selectedSlot else {
            showToast("请先在遥控器上选择一个按键")
            return nil
        }

        let identifier = UUID().uuidString.lowercased()
        let shortcut = SmartAction(
            id: "recorded-keyboard-shortcut-\(identifier)",
            actionID: "recorded-keyboard-shortcut-\(identifier)",
            title: "高级键盘映射",
            subtitle: displayName,
            symbol: "keyboard",
            tint: .gray,
            stepCount: 1,
            steps: [.keystroke(keyCode: keyCode, flags: flags, name: displayName)]
        )
        smartActions.append(shortcut)
        refreshShortcutBindings()
        let action = shortcut.remoteAction
        assign(action, to: selectedSlot)
        return action
    }

    /// Creates (or reuses) an executable action for an exact `.app` bundle and
    /// immediately assigns it to the selected physical button/trigger.
    @discardableResult
    func assignApplication(
        at applicationURL: URL,
        displayName: String? = nil
    ) -> RemoteAction? {
        guard let selectedSlot else {
            showToast("请先在遥控器上选择一个按键")
            return nil
        }

        let url = applicationURL.standardizedFileURL
        guard url.isFileURL,
              url.pathExtension.localizedCaseInsensitiveCompare("app") == .orderedSame else {
            showToast("请选择一个 macOS 应用程序（.app）")
            return nil
        }

        let requestedName = displayName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (requestedName?.isEmpty == false ? requestedName : nil)
            ?? Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        let step = SmartActionStep.applicationPath(path: url.path, name: name)

        let workflow: SmartAction
        if let existing = smartActions.first(where: { $0.steps == [step] }) {
            workflow = existing
        } else {
            let identifier = UUID().uuidString.lowercased()
            workflow = SmartAction(
                id: "selected-application-\(identifier)",
                actionID: "selected-application-\(identifier)",
                title: "打开 \(name)",
                subtitle: "启动并切换到 \(name)",
                symbol: "app.dashed",
                tint: .blue,
                stepCount: 1,
                steps: [step]
            )
            smartActions.append(workflow)
            refreshShortcutBindings()
        }

        let action = workflow.remoteAction
        assign(action, to: selectedSlot)
        return action
    }

    func chooseApplicationForSelectedSlot() {
        guard selectedSlot != nil else {
            showToast("请先在遥控器上选择一个按键")
            return
        }

        let panel = NSOpenPanel()
        panel.title = "选择要打开的应用程序"
        panel.message = "选择后，按下遥控器按键即可启动并切换到该 App。"
        panel.prompt = "选择"
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.resolvesAliases = true

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor [weak self] in
                _ = self?.assignApplication(at: url)
            }
        }
    }

    func beginDragging(_ action: RemoteAction) {
        draggedActionID = action.id
    }

    func cancelDragging() {
        draggedActionID = nil
    }

    func simulateRandomPress() {
        let candidates = RemoteButtonSlot.demoSlots
        let slot = candidates.randomElement() ?? candidates[0]
        selectedSlotID = slot.id
        pressedSlotID = slot.id

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { [weak self] in
            guard self?.pressedSlotID == slot.id else { return }
            self?.pressedSlotID = nil
        }
    }

    func toggleConnection() {
        openBluetoothSettings()
        showToast(connectionState == .connected
            ? "请在系统蓝牙设置中管理当前连接"
            : "进入配对模式后，在系统蓝牙中连接遥控器")
    }

    func startBackend() {
        guard runtimeServicesEnabled else { return }
        defer { presentConfigurationLoadWarningIfNeeded() }
        scheduleAutomaticUpdateCheckIfNeeded()
        refreshPermissions()
        guard remoteIsManaged else {
            backendCoordinator.stop()
            inputBackendReady = false
            devicePresent = false
            connectionState = .disconnected
            backendLog = "设备已从 MiCoding 移除"
            return
        }
        refreshDevicePresence()
        refreshBatteryLevel()
        guard inputServiceEnabled else {
            inputBackendReady = false
            backendLog = "MiCoding 输入服务已停用"
            return
        }
        refreshShortcutBindings()
        backendCoordinator.startAutomationTriggers()
        guard permissions.inputMonitoringGranted else {
            inputBackendReady = false
            backendLog = devicePresent
                ? "已检测到遥控器；授予输入监控权限后即可读取按键"
                : "等待 Xiaomi Remote 2 Pro 连接"
            return
        }
        backendCoordinator.start()
    }

    func restartBackend(announce: Bool = false) {
        backendCoordinator.stop()
        startBackend()
        guard announce else { return }

        if !inputServiceEnabled {
            showToast("MiCoding 输入服务已停用")
        } else if !permissions.inputMonitoringGranted {
            showToast("需要输入监控权限后才能启动输入服务")
        } else {
            showToast("MiCoding 输入服务已重新启动")
        }
    }

    func stopBackend() {
        backendCoordinator.stop()
    }

    func selectProfile(_ profile: AppProfile) {
        selectedProfileID = profile.id
        showsApplicationPicker = false
        persistConfiguration()
    }

    func isApplicationProfileEnabled(_ profile: AppProfile) -> Bool {
        profiles.contains(where: { $0.id == profile.id })
    }

    func toggleApplicationProfile(_ profile: AppProfile) {
        guard profile.id != "global" else { return }
        if isApplicationProfileEnabled(profile) {
            removeApplicationProfile(profile)
        } else {
            removedProfileIDs.remove(profile.id)
            profiles.append(profile)
            assignmentsByProfile[profile.id] = assignmentsByProfile[profile.id] ?? [:]
            persistConfiguration()
            showToast("已添加 \(profile.title) Profile")
        }
    }

    func addApplicationProfile(_ profile: AppProfile) {
        removedProfileIDs.remove(profile.id)
        if !profiles.contains(where: { $0.id == profile.id }) {
            profiles.append(profile)
            assignmentsByProfile[profile.id] = assignmentsByProfile[profile.id] ?? [:]
        }
        selectProfile(profile)
        showToast("已添加 \(profile.title) Profile")
    }

    /// Installs a remote-first Codex/Claude layout for hands-free coding.
    /// Unrelated global buttons stay untouched so the preset is safe to apply
    /// over an existing device configuration.
    func installAIVibeCodingPreset() {
        let codexID = "com.openai.codex"
        let claudeID = "com.anthropic.claudefordesktop"

        for profileID in [codexID, claudeID] {
            removedProfileIDs.remove(profileID)
            if let profile = AppProfile.profiles.first(where: { $0.id == profileID }),
               !profiles.contains(where: { $0.id == profileID }) {
                profiles.append(profile)
            }
        }

        assignmentsByProfile["global", default: [:]]["power"] = "open-codex"
        assignmentsByProfile["global", default: [:]]["voice"] = "typeless-dictation"
        doubleTapAssignmentsByProfile["global", default: [:]]["power"] = "open-claude"
        doubleTapAssignmentsByProfile["global", default: [:]]["voice"] = nil
        holdAssignmentsByProfile["global", default: [:]]["voice"] = nil

        assignmentsByProfile[codexID] = [
            "power": "open-codex",
            "voice": "typeless-dictation",
            "left": "codex-previous-chat",
            "right": "codex-next-chat",
            "ok": "ai-submit",
            "back": "ai-cancel",
            "home": "codex-new-chat",
            "menu": "show-actions-ring",
            "tv": "codex-open-terminal"
        ]
        doubleTapAssignmentsByProfile[codexID, default: [:]]["power"] = "open-claude"
        doubleTapAssignmentsByProfile[codexID, default: [:]]["voice"] = nil
        holdAssignmentsByProfile[codexID, default: [:]]["voice"] = nil

        assignmentsByProfile[claudeID] = [
            "power": "open-claude",
            "voice": "typeless-dictation",
            "ok": "ai-submit",
            "back": "ai-cancel",
            "home": "claude-new-conversation",
            "menu": "show-actions-ring",
            "tv": "ai-attach-file"
        ]
        doubleTapAssignmentsByProfile[claudeID, default: [:]]["power"] = "open-codex"
        doubleTapAssignmentsByProfile[claudeID, default: [:]]["voice"] = nil
        holdAssignmentsByProfile[claudeID, default: [:]]["voice"] = nil

        actionsRingAssignmentsByProfile[codexID] = [
            "ai-attach-file",
            "codex-new-chat",
            "ai-submit",
            "codex-open-terminal",
            "codex-toggle-file-tree",
            "codex-toggle-review",
            "codex-previous-chat",
            "codex-next-chat"
        ]
        actionsRingAssignmentsByProfile[claudeID] = [
            "open-codex",
            "claude-new-conversation",
            "ai-submit",
            "ai-newline",
            "ai-attach-file",
            "copy",
            "paste",
            "ai-cancel"
        ]
        if selectedActionsRingProfileID == codexID || selectedActionsRingProfileID == claudeID {
            actionsRingActionIDs = actionsRingAssignmentsByProfile[selectedActionsRingProfileID]
                ?? AppStore.defaultActionsRingActionIDs
        }

        persistConfiguration()
        showToast("已安装 Codex / Claude 躺平编程预设")
    }

    func removeApplicationProfile(_ profile: AppProfile) {
        guard profile.id != "global" else { return }

        profiles.removeAll(where: { $0.id == profile.id })
        assignmentsByProfile[profile.id] = nil
        holdAssignmentsByProfile[profile.id] = nil
        doubleTapAssignmentsByProfile[profile.id] = nil
        actionsRingAssignmentsByProfile[profile.id] = nil
        removedProfileIDs.insert(profile.id)

        if selectedProfileID == profile.id {
            selectedProfileID = "global"
        }
        if selectedActionsRingProfileID == profile.id {
            selectedActionsRingProfileID = "global"
            actionsRingActionIDs = actionsRingAssignmentsByProfile["global"]
                ?? AppStore.defaultActionsRingActionIDs
        }

        persistConfiguration()
        showToast("已移除 \(profile.title) Profile")
    }

    func setDarkAppearance(_ enabled: Bool) {
        setAppearanceMode(enabled ? .dark : .light)
    }

    func setAppearanceMode(_ mode: AppAppearanceMode) {
        appearanceMode = mode
        useDarkAppearance = mode == .dark
        persistConfiguration()
    }

    func setActionNotifications(_ enabled: Bool) {
        showActionNotifications = enabled
        persistConfiguration()
    }

    func setAutomaticUpdates(_ enabled: Bool) {
        automaticUpdatesEnabled = enabled
        persistConfiguration()
        if enabled {
            hasScheduledAutomaticUpdateCheck = false
            scheduleAutomaticUpdateCheckIfNeeded()
        }
    }

    func checkForUpdates(announceResult: Bool = true) {
        guard updateCheckTask == nil else {
            if announceResult { showToast("正在检查更新…") }
            return
        }

        softwareUpdateStatus = .checking
        if announceResult { showToast("正在检查更新…") }
        let currentVersion = appVersion
        updateCheckTask = Task { [weak self] in
            do {
                let release = try await SoftwareUpdateService.latestRelease()
                guard !Task.isCancelled, let self else { return }
                if let release,
                   SoftwareUpdateService.isNewer(release.version, than: currentVersion) {
                    softwareUpdateStatus = .available(release)
                    showToast("发现新版本 \(release.version)，可前往下载")
                } else if release != nil {
                    softwareUpdateStatus = .current(version: currentVersion)
                    if announceResult { showToast("当前已是最新发布版本") }
                } else {
                    softwareUpdateStatus = .unpublished
                    if announceResult { showToast("项目尚未发布可下载的安装包") }
                }
            } catch {
                guard !Task.isCancelled, let self else { return }
                SoftwareUpdateService.logFailure(error)
                softwareUpdateStatus = .failed
                if announceResult { showToast("暂时无法连接更新服务") }
            }
            self?.updateCheckTask = nil
        }
    }

    func openUpdatePage() {
        NSWorkspace.shared.open(
            softwareUpdateStatus.releaseURL ?? SoftwareUpdateService.releasesPageURL
        )
    }

    private func scheduleAutomaticUpdateCheckIfNeeded() {
        guard runtimeServicesEnabled,
              automaticUpdatesEnabled,
              !hasScheduledAutomaticUpdateCheck else { return }
        hasScheduledAutomaticUpdateCheck = true
        checkForUpdates(announceResult: false)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.2.0"
    }

    func setInputServiceEnabled(_ enabled: Bool) {
        inputServiceEnabled = enabled
        if enabled {
            startBackend()
        } else {
            backendCoordinator.stop()
            inputBackendReady = false
            backendLog = "MiCoding 输入服务已停用"
        }
        persistConfiguration()
    }

    func makeDeviceBackupData(exportedAt: Date = Date()) throws -> Data {
        let backup = DeviceConfigurationBackup(
            deviceID: RemoteDevice.remote2Pro.id,
            exportedAt: exportedAt,
            configuration: currentConfiguration()
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    func restoreDeviceBackupData(_ data: Data) throws {
        let backup = try JSONDecoder().decode(DeviceConfigurationBackup.self, from: data)
        guard backup.version == DeviceConfigurationBackup.currentVersion else {
            throw DeviceConfigurationBackupError.unsupportedVersion(backup.version)
        }
        guard backup.deviceID == RemoteDevice.remote2Pro.id else {
            throw DeviceConfigurationBackupError.incompatibleDevice(backup.deviceID)
        }

        let saved = backup.configuration
        guard saved.version == PersistedConfiguration.currentVersion else {
            throw DeviceConfigurationBackupError.unsupportedConfigurationVersion(saved.version)
        }
        assignmentsByProfile = saved.assignmentsByProfile
        migrateLegacyAssignments()
        holdAssignmentsByProfile = saved.holdAssignmentsByProfile
        doubleTapAssignmentsByProfile = saved.doubleTapAssignmentsByProfile
        backendSettings = saved.settings
        holdMilliseconds = saved.settings.holdMilliseconds
        doubleTapMilliseconds = saved.settings.doubleTapMilliseconds
        debounceMilliseconds = saved.settings.debounceMilliseconds ?? 30
        backendCoordinator.configure(settings: backendSettings)

        profiles = AppProfile.profiles
        restoreCustomProfiles()
        removedProfileIDs = Set(saved.removedProfileIDs ?? [])
        profiles.removeAll { profile in
            profile.id != "global" && removedProfileIDs.contains(profile.id)
        }
        selectedProfileID = profiles.contains(where: { $0.id == saved.lastProfileID })
            ? saved.lastProfileID
            : "global"

        let savedRingActions = migratedActionsRingActionIDs(saved.actionsRingActionIDs ?? [])
        let savedRingAssignments = (saved.actionsRingAssignmentsByProfile ?? [:])
            .filter { $0.value.count == 8 }
            .mapValues(migratedActionsRingActionIDs)
        if !savedRingAssignments.isEmpty {
            actionsRingAssignmentsByProfile = savedRingAssignments
        } else if savedRingActions.count == 8 {
            actionsRingAssignmentsByProfile = ["global": savedRingActions]
        } else {
            actionsRingAssignmentsByProfile = ["global": AppStore.defaultActionsRingActionIDs]
        }
        if actionsRingAssignmentsByProfile["global"] == nil {
            actionsRingAssignmentsByProfile["global"] = AppStore.defaultActionsRingActionIDs
        }
        actionsRingSize = saved.actionsRingSize ?? .medium
        let savedActionsRingProfileID = saved.lastActionsRingProfileID ?? "global"
        selectedActionsRingProfileID = profiles.contains(where: { $0.id == savedActionsRingProfileID })
            ? savedActionsRingProfileID
            : "global"
        actionsRingActionIDs = actionsRingAssignmentsByProfile[selectedActionsRingProfileID]
            ?? actionsRingAssignmentsByProfile["global"]
            ?? AppStore.defaultActionsRingActionIDs

        smartActions.removeAll()
        restoreSmartActions(saved.customSmartActions ?? [])
        selectedSlotID = nil
        selectedTrigger = .tap
        refreshShortcutBindings()
        configurationPersistenceBlocked = false
        configurationLoadWarning = nil
        persistConfiguration()
        if inputServiceEnabled {
            restartBackend()
        }
    }

    private func migratedActionsRingActionIDs(_ actionIDs: [String]) -> [String] {
        actionIDs == AppStore.legacyDefaultActionsRingActionIDs
            ? AppStore.defaultActionsRingActionIDs
            : actionIDs
    }

    func resetDeviceConfiguration() {
        assignmentsByProfile = ["global": [:]]
        holdAssignmentsByProfile = [:]
        doubleTapAssignmentsByProfile = [:]
        profiles = AppProfile.profiles
        removedProfileIDs = []
        selectedProfileID = "global"
        selectedSlotID = nil
        selectedTrigger = .tap
        pendingAssignmentActionID = nil
        draggedActionID = nil
        objectWillChange.send()
        persistConfiguration()
        showToast("已清除遥控器的所有按键配置")
    }

    func setPermissionReminders(_ enabled: Bool) {
        showPermissionReminders = enabled
        persistConfiguration()
    }

    func setExperienceRecommendations(_ enabled: Bool) {
        showExperienceRecommendations = enabled
        persistConfiguration()
    }

    func setConnectionNotifications(_ enabled: Bool) {
        showConnectionNotifications = enabled
        persistConfiguration()
    }

    func setLowBatteryNotifications(_ enabled: Bool) {
        guard showLowBatteryNotifications != enabled else { return }
        showLowBatteryNotifications = enabled
        persistConfiguration()
        if enabled,
           let batteryLevel,
           let warning = recordBatteryLevel(batteryLevel) {
            displayToast(warning)
        }
    }

    func setHoldMilliseconds(_ value: Int) {
        let normalized = min(max(value, 250), 800)
        guard holdMilliseconds != normalized else { return }
        holdMilliseconds = normalized
        backendSettings.holdMilliseconds = normalized
        backendCoordinator.configure(settings: backendSettings)
        persistConfiguration()
    }

    func setDoubleTapMilliseconds(_ value: Int) {
        let normalized = min(max(value, 150), 500)
        guard doubleTapMilliseconds != normalized else { return }
        doubleTapMilliseconds = normalized
        backendSettings.doubleTapMilliseconds = normalized
        backendCoordinator.configure(settings: backendSettings)
        persistConfiguration()
    }

    func setDebounceMilliseconds(_ value: Int) {
        let normalized = min(max(value, 10), 100)
        guard debounceMilliseconds != normalized else { return }
        debounceMilliseconds = normalized
        backendSettings.debounceMilliseconds = normalized
        backendCoordinator.configure(settings: backendSettings)
        persistConfiguration()
    }

    @discardableResult
    func addSmartAction(_ action: SmartAction) -> SmartAction {
        if let existing = smartActions.first(where: { $0.id == action.id }) {
            return existing
        }
        guard action.isEligibleWorkflow else {
            showToast("无法创建“\(action.title)”：工作流包含不适用的动作")
            return action
        }
        let (normalized, conflictTitle) = normalizedSmartAction(
            action,
            against: smartActions
        )
        smartActions.append(normalized)
        refreshShortcutBindings()
        persistConfiguration()
        if let conflictTitle {
            showToast("已创建“\(normalized.title)”，但因快捷键与“\(conflictTitle)”冲突已停用")
        } else {
            showToast("已创建“\(normalized.title)”")
        }
        return normalized
    }

    @discardableResult
    func updateSmartAction(_ action: SmartAction) -> SmartAction {
        guard let index = smartActions.firstIndex(where: { $0.id == action.id }) else {
            return action
        }
        guard action.isEligibleWorkflow else {
            showToast("无法更新“\(action.title)”：工作流包含不适用的动作")
            return smartActions[index]
        }
        let (normalized, conflictTitle) = normalizedSmartAction(
            action,
            against: smartActions
        )
        smartActions[index] = normalized
        refreshShortcutBindings()
        persistConfiguration()
        if let conflictTitle {
            showToast("已更新“\(normalized.title)”，但因快捷键与“\(conflictTitle)”冲突已停用")
        } else {
            showToast("已更新“\(normalized.title)”")
        }
        return normalized
    }

    @discardableResult
    func setSmartActionEnabled(id: String, enabled: Bool) -> Bool {
        guard let index = smartActions.firstIndex(where: { $0.id == id }),
              smartActions[index].isEnabled != enabled else {
            return smartActions.first(where: { $0.id == id })?.isEnabled == enabled
        }
        if enabled,
           let conflictTitle = conflictingShortcutActionTitle(for: smartActions[index]) {
            showToast("无法启用：全局快捷键已用于“\(conflictTitle)”")
            return false
        }
        let action = smartActions[index].withEnabled(enabled)
        smartActions[index] = action
        refreshShortcutBindings()
        persistConfiguration()
        showToast("已\(enabled ? "启用" : "停用")“\(action.title)”")
        return true
    }

    func removeSmartAction(id: String) {
        guard let action = smartActions.first(where: { $0.id == id }) else { return }
        smartActions.removeAll(where: { $0.id == id })
        refreshShortcutBindings()
        removeAssignments(to: action.actionID, from: &assignmentsByProfile)
        removeAssignments(to: action.actionID, from: &holdAssignmentsByProfile)
        removeAssignments(to: action.actionID, from: &doubleTapAssignmentsByProfile)
        if pendingAssignmentActionID == action.actionID {
            pendingAssignmentActionID = nil
        }
        if draggedActionID == action.actionID {
            draggedActionID = nil
        }
        objectWillChange.send()
        persistConfiguration()
        showToast("已删除“\(action.title)”")
    }

    func refreshPermissions() {
        permissions = PermissionService.current()
    }

    func refreshRuntimeState() {
        guard runtimeServicesEnabled else { return }
        let previousPermissions = permissions
        refreshPermissions()
        refreshDeviceInformation()
        guard remoteIsManaged else { return }
        if !previousPermissions.accessibilityGranted,
           permissions.accessibilityGranted {
            backendCoordinator.startAutomationTriggers()
        }
        if previousPermissions.inputMonitoringGranted,
           !permissions.inputMonitoringGranted {
            backendCoordinator.stopInput()
            inputBackendReady = false
            backendLog = devicePresent
                ? "输入监控权限已撤销；已恢复遥控器原始按键"
                : "输入监控权限已撤销"
        } else if !previousPermissions.inputMonitoringGranted,
                  permissions.inputMonitoringGranted {
            restartBackend()
        }
    }

    func refreshDeviceInformation() {
        guard runtimeServicesEnabled else { return }
        guard remoteIsManaged || showsConnectionTypePicker else { return }
        refreshDevicePresence()
        refreshBatteryLevel()
    }

    private func refreshDevicePresence() {
        guard remoteIsManaged || showsConnectionTypePicker else {
            devicePresent = false
            connectionState = .disconnected
            return
        }
        devicePresent = HIDDevicePresenceService.isPresent(
            vendorID: backendSettings.remoteVendorID,
            productID: backendSettings.remoteProductID
        )
        connectionState = devicePresent ? .connected : .disconnected
        if !devicePresent {
            batteryLevel = nil
            firmwareVersion = nil
            lowBatteryWarningIssued = false
            lastBatteryRefreshDate = nil
            batteryRefreshTask?.cancel()
            batteryRefreshTask = nil
        }
    }

    func checkDeviceInformation() {
        lastBatteryRefreshDate = nil
        refreshDevicePresence()
        guard devicePresent else {
            showToast("未检测到遥控器，请先唤醒设备")
            return
        }
        refreshBatteryLevel(announceResult: true)
    }

    private func refreshBatteryLevel(announceResult: Bool = false) {
        guard devicePresent else { return }
        if let lastBatteryRefreshDate,
           Date().timeIntervalSince(lastBatteryRefreshDate) < 30 {
            return
        }

        lastBatteryRefreshDate = Date()
        let remoteVendorID = backendSettings.remoteVendorID
        let remoteProductID = backendSettings.remoteProductID
        batteryRefreshTask?.cancel()
        batteryRefreshTask = Task { [weak self] in
            let snapshot = await Task.detached(priority: .utility) {
                BluetoothBatteryService.currentSnapshot(
                    deviceName: "小米蓝牙语音遥控器",
                    vendorID: remoteVendorID,
                    productID: remoteProductID
                )
            }.value
            guard !Task.isCancelled else { return }
            // `system_profiler` can transiently omit Bluetooth details while the
            // controller refreshes. Keep the last confirmed value instead of
            // flashing an unavailable state between successful reads.
            let lowBatteryWarning = snapshot?.batteryLevel.flatMap {
                self?.recordBatteryLevel($0)
            }
            if let firmwareVersion = snapshot?.firmwareVersion {
                self?.firmwareVersion = firmwareVersion
            }
            if let lowBatteryWarning {
                self?.displayToast(lowBatteryWarning)
            } else if announceResult {
                switch (snapshot?.batteryLevel, snapshot?.firmwareVersion) {
                case let (level?, firmwareVersion?):
                    self?.showToast("电量 \(level)% · 固件 \(firmwareVersion)")
                case let (level?, nil):
                    self?.showToast("已读取电量 \(level)% · 固件未上报")
                case let (nil, firmwareVersion?):
                    self?.showToast("已读取固件 \(firmwareVersion) · 电量未上报")
                case (nil, nil):
                    self?.showToast("设备已连接，但 macOS 未上报电量和固件")
                }
            }
            self?.batteryRefreshTask = nil
        }
    }

    /// Stores the newest confirmed level and returns a warning only when the
    /// device first enters the low-battery band. A recovery above 20% arms the
    /// next warning, so the minute refresh never produces repeated overlays.
    @discardableResult
    func recordBatteryLevel(_ level: Int) -> String? {
        batteryLevel = min(max(level, 0), 100)
        guard batteryLevel ?? 100 <= 20 else {
            lowBatteryWarningIssued = false
            return nil
        }
        guard showLowBatteryNotifications, !lowBatteryWarningIssued else { return nil }
        lowBatteryWarningIssued = true
        return "遥控器电量低：\(batteryLevel ?? level)%"
    }

    func requestAccessibilityPermission() {
        PermissionService.requestAccessibility()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshPermissions()
        }
    }

    func requestInputMonitoringPermission() {
        PermissionService.requestInputMonitoring()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshPermissions()
        }
    }

    func openInputMonitoringSettings() {
        openSystemSettings(
            urls: [
                "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
                "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ListenEvent"
            ],
            failureMessage: "请在系统设置中允许 MiCoding 的输入监控权限"
        )
    }

    func openAccessibilitySettings() {
        openSystemSettings(
            urls: [
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
                "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
            ],
            failureMessage: "请在系统设置中允许 MiCoding 的辅助功能权限"
        )
    }

    func openBluetoothSettings() {
        openSystemSettings(
            urls: [
                "x-apple.systempreferences:com.apple.BluetoothSettings",
                "x-apple.systempreferences:com.apple.preferences.Bluetooth"
            ],
            failureMessage: "请在系统设置中打开蓝牙"
        )
    }

    func openDisplaysSettings() {
        openSystemSettings(
            urls: Self.displaysSettingsURLs,
            failureMessage: "请在系统设置的“显示器”中配置通用控制"
        )
    }

    func openHandoffSettings() {
        openSystemSettings(
            urls: Self.handoffSettingsURLs,
            failureMessage: "请在系统设置的“隔空投送与接力”中打开接力"
        )
    }

    func openLanguageSettings() {
        openSystemSettings(
            urls: Self.languageSettingsURLs,
            failureMessage: "请在系统设置的“语言与地区”中更改系统语言"
        )
    }

    func runAction(
        actionID: String,
        title: String,
        completion: (@MainActor (ActionExecutionResult) -> Void)? = nil
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await self.backendCoordinator.execute(
                actionID: actionID,
                source: "手动运行"
            )
            switch result {
            case .success:
                self.showToast("已运行“\(title)”")
            case let .failure(message):
                self.showImportantToast("无法运行“\(title)”：\(message)")
            }
            completion?(result)
        }
    }

    func previewSmartAction(title: String, steps: [SmartActionStep]) {
        let commands = steps.map(\.command)
        guard !commands.isEmpty,
              steps.allSatisfy(\.isValidForSmartAction),
              !commands.contains(.none) else {
            showToast("请先完成所有步骤的配置")
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await self.backendCoordinator.execute(
                command: .sequence(commands),
                source: "试运行"
            )
            switch result {
            case .success:
                self.showToast("已完成试运行“\(title)”")
            case let .failure(message):
                self.showImportantToast("试运行“\(title)”失败：\(message)")
            }
        }
    }

    func testSelectedAction() {
        guard let selectedSlot,
              let action = action(for: selectedSlot.id, trigger: selectedTrigger) else {
            showToast("当前按键尚未分配动作")
            return
        }

        pressedSlotID = selectedSlot.id
        runAction(actionID: action.id, title: action.title)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { [weak self] in
            guard self?.pressedSlotID == selectedSlot.id else { return }
            self?.pressedSlotID = nil
        }
    }

    private func executionActionID(
        bundleIdentifier: String?,
        slotID: String,
        trigger: RemoteTrigger
    ) -> String? {
        let profileID = profiles.first(where: {
            $0.bundleIdentifier == bundleIdentifier
        })?.id

        let table: [String: [String: String]]
        switch trigger {
        case .tap:
            table = assignmentsByProfile
        case .hold:
            table = holdAssignmentsByProfile
        case .doubleTap:
            table = doubleTapAssignmentsByProfile
        }

        let eligibleActionID: (String) -> String? = { actionID in
            guard self.isActionExecutionEnabled(actionID),
                  let slot = RemoteButtonSlot.demoSlots.first(where: { $0.id == slotID }),
                  let action = self.resolvedAction(id: actionID),
                  slot.accepts(action, trigger: trigger) else { return nil }
            return actionID
        }

        if let profileID, let actionID = table[profileID]?[slotID] {
            return eligibleActionID(actionID)
        }
        guard let actionID = table["global"]?[slotID] else { return nil }
        return eligibleActionID(actionID)
    }

    private func refreshShortcutBindings() {
        let enabledActions = smartActions.filter(\.isEnabled)
        var registeredShortcuts = Set<ShortcutSignature>()
        let shortcutBindings = enabledActions.flatMap { action in
            (action.triggers ?? []).compactMap { trigger -> GlobalShortcutBinding? in
                guard case let .shortcut(keyCode, flags, _) = trigger else { return nil }
                let signature = ShortcutSignature(keyCode: keyCode, flags: flags)
                guard registeredShortcuts.insert(signature).inserted else { return nil }
                return GlobalShortcutBinding(
                    actionID: action.actionID,
                    keyCode: keyCode,
                    flags: flags
                )
            }
        }
        let applicationTriggerBindings = enabledActions.flatMap { action in
            (action.triggers ?? []).compactMap { trigger -> ApplicationTriggerBinding? in
                guard case let .application(bundleIdentifier, _) = trigger else { return nil }
                return ApplicationTriggerBinding(
                    actionID: action.actionID,
                    bundleIdentifier: bundleIdentifier
                )
            }
        }
        backendCoordinator.configure(shortcutBindings: shortcutBindings)
        backendCoordinator.configure(applicationTriggerBindings: applicationTriggerBindings)
    }

    private func conflictingShortcutActionTitle(for action: SmartAction) -> String? {
        normalizedSmartAction(action.withEnabled(true), against: smartActions).conflictTitle
    }

    private func shortcutSignatures(for action: SmartAction) -> Set<ShortcutSignature> {
        Set((action.triggers ?? []).compactMap { trigger in
            guard case let .shortcut(keyCode, flags, _) = trigger else { return nil }
            return ShortcutSignature(keyCode: keyCode, flags: flags)
        })
    }

    private func normalizedSmartAction(
        _ action: SmartAction,
        against candidates: [SmartAction]
    ) -> (action: SmartAction, conflictTitle: String?) {
        guard action.isEnabled else { return (action, nil) }
        let signatures = shortcutSignatures(for: action)
        guard !signatures.isEmpty else { return (action, nil) }

        let conflict = candidates.first { candidate in
            candidate.id != action.id
                && candidate.isEnabled
                && !signatures.isDisjoint(with: shortcutSignatures(for: candidate))
        }
        guard let conflict else { return (action, nil) }
        return (action.withEnabled(false), conflict.title)
    }

    private func isActionExecutionEnabled(_ actionID: String) -> Bool {
        smartActions.first(where: { $0.actionID == actionID })?.isEnabled ?? true
    }

    func command(for actionID: String) -> ActionCommand? {
        if let action = smartActions.first(where: { $0.actionID == actionID }),
           let steps = action.steps {
            let commands = steps.map(\.command)
            guard !commands.isEmpty,
                  steps.allSatisfy(\.isValidForSmartAction),
                  !commands.contains(.none) else { return nil }
            return .sequence(commands)
        }

        let command = ActionCommand.command(for: actionID)
        return command == .none ? nil : command
    }

    private func resolvedAction(id actionID: String) -> RemoteAction? {
        smartActions.first(where: { $0.actionID == actionID })?.remoteAction
            ?? RemoteAction.catalog.first(where: { $0.id == actionID })
    }

    private func eligibleAction(
        id actionID: String,
        for placement: RemoteActionPlacement
    ) -> RemoteAction? {
        guard let action = resolvedAction(id: actionID),
              action.isEligible(for: placement) else { return nil }
        if placement == .actionsRing,
           let smartAction = smartActions.first(where: { $0.actionID == actionID }) {
            guard smartAction.isEnabled,
                  smartAction.triggers?.contains(.actionsRing) == true else { return nil }
        }
        return action
    }

    private func removeAssignments(
        to actionID: String,
        from table: inout [String: [String: String]]
    ) {
        for profileID in Array(table.keys) {
            table[profileID] = table[profileID]?.filter { $0.value != actionID }
        }
    }

    private func handlePhysicalInput(_ event: RemoteInputEvent) {
        selectedSlotID = event.slotID
        switch event.phase {
        case .began:
            pressedSlotID = event.slotID
            if showsFeatureOverview {
                detectedPhysicalKeyIDs.insert(event.slotID)
            }
        case .ended:
            if pressedSlotID == event.slotID {
                pressedSlotID = nil
            }
        }
    }

    private func persistConfiguration() {
        guard !configurationPersistenceBlocked else {
            backendLog = "配置保存已暂停：请先恢复或移走无法读取的 config.json"
            return
        }
        do {
            try configurationStore.save(currentConfiguration())
            hasPresentedConfigurationSaveWarning = false
        } catch {
            backendLog = "保存本地配置失败：\(error.localizedDescription)"
            if !hasPresentedConfigurationSaveWarning {
                hasPresentedConfigurationSaveWarning = true
                showImportantToast("无法保存设置，请检查 MiCoding 的本地数据目录")
            }
        }
    }

    private func presentConfigurationLoadWarningIfNeeded() {
        guard !hasPresentedConfigurationLoadWarning,
              let configurationLoadWarning else { return }
        hasPresentedConfigurationLoadWarning = true
        showImportantToast(configurationLoadWarning)
    }

    private func currentConfiguration() -> PersistedConfiguration {
        PersistedConfiguration(
            settings: backendSettings,
            assignmentsByProfile: assignmentsByProfile,
            holdAssignmentsByProfile: holdAssignmentsByProfile,
            doubleTapAssignmentsByProfile: doubleTapAssignmentsByProfile,
            lastProfileID: selectedProfileID,
            useDarkAppearance: useDarkAppearance,
            appearanceMode: appearanceMode,
            automaticUpdatesEnabled: automaticUpdatesEnabled,
            remoteIsManaged: remoteIsManaged,
            inputServiceEnabled: inputServiceEnabled,
            showActionNotifications: showActionNotifications,
            showPermissionReminders: showPermissionReminders,
            showExperienceRecommendations: showExperienceRecommendations,
            showConnectionNotifications: showConnectionNotifications,
            showLowBatteryNotifications: showLowBatteryNotifications,
            customSmartActions: smartActions.map(\.persistedRepresentation),
            removedProfileIDs: removedProfileIDs.sorted(),
            actionsRingActionIDs: actionsRingActionIDs,
            actionsRingSize: actionsRingSize,
            actionsRingAssignmentsByProfile: actionsRingAssignmentsByProfile,
            lastActionsRingProfileID: selectedActionsRingProfileID
        )
    }

    private func openSystemSettings(urls: [String], failureMessage: String) {
        for value in urls {
            if let url = URL(string: value), NSWorkspace.shared.open(url) { return }
        }
        showToast(failureMessage)
    }

    private func restoreCustomProfiles() {
        let builtInIDs = Set(AppProfile.profiles.map(\.id))
        let savedIDs = Set(assignmentsByProfile.keys)
            .union(holdAssignmentsByProfile.keys)
            .union(doubleTapAssignmentsByProfile.keys)
            .subtracting(builtInIDs)

        for bundleIdentifier in savedIDs.sorted() {
            guard let applicationURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: bundleIdentifier
            ) else { continue }
            let applicationBundle = Bundle(url: applicationURL)
            let title = applicationBundle?.object(
                forInfoDictionaryKey: "CFBundleDisplayName"
            ) as? String
                ?? applicationBundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? applicationURL.deletingPathExtension().lastPathComponent
            profiles.append(
                AppProfile(
                    id: bundleIdentifier,
                    title: title,
                    subtitle: "应用专属配置",
                    symbol: "app.dashed",
                    tint: .gray,
                    bundleIdentifier: bundleIdentifier
                )
            )
        }
    }

    private func refreshAvailableApplicationProfiles() {
        var candidates: [String: AppProfile] = [:]
        for profile in AppProfile.profiles + profiles {
            guard let bundleIdentifier = profile.bundleIdentifier else { continue }
            candidates[bundleIdentifier] = profile
        }
        let fileManager = FileManager.default
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]

        func scan(_ directory: URL, depth: Int) {
            guard depth <= 2,
                  let children = try? fileManager.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                  ) else { return }

            for url in children {
                if url.pathExtension.localizedCaseInsensitiveCompare("app") == .orderedSame {
                    guard let bundle = Bundle(url: url),
                          let bundleIdentifier = bundle.bundleIdentifier,
                          bundleIdentifier != Bundle.main.bundleIdentifier else { continue }
                    let title = url.deletingPathExtension().lastPathComponent
                    if candidates[bundleIdentifier] == nil {
                        candidates[bundleIdentifier] = AppProfile(
                            id: bundleIdentifier,
                            title: title,
                            subtitle: "应用专属配置",
                            symbol: "app.dashed",
                            tint: .gray,
                            bundleIdentifier: bundleIdentifier
                        )
                    }
                } else if depth < 2,
                          (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    scan(url, depth: depth + 1)
                }
            }
        }

        roots.forEach { scan($0, depth: 0) }
        availableApplicationProfiles = candidates.values.sorted {
            let lhsStartsWithASCII = $0.title.unicodeScalars.first?.isASCII == true
            let rhsStartsWithASCII = $1.title.unicodeScalars.first?.isASCII == true
            if lhsStartsWithASCII != rhsStartsWithASCII {
                return lhsStartsWithASCII
            }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    @discardableResult
    private func restoreSmartActions(_ savedActions: [PersistedSmartAction]) -> Bool {
        let restored = savedActions.compactMap(SmartAction.restored(from:))
        var didNormalize = restored.count != savedActions.count
        smartActions = restored.reduce(into: []) { result, action in
            guard !result.contains(where: { $0.id == action.id }) else { return }
            let normalized = normalizedSmartAction(action, against: result).action
            if normalized.isEnabled != action.isEnabled {
                didNormalize = true
            }
            result.append(normalized)
        }
        if smartActions.count != restored.count {
            didNormalize = true
        }
        return didNormalize
    }

    func showToast(_ message: String) {
        guard showActionNotifications else { return }
        displayToast(message)
    }

    /// Errors and user-requested recovery guidance must remain visible even
    /// when routine action overlays are disabled in Settings.
    func showImportantToast(_ message: String) {
        displayToast(message)
    }

    private func showConnectionToast(_ message: String) {
        guard showConnectionNotifications else { return }
        displayToast(message)
    }

    private func displayToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            guard self?.toastMessage == message else { return }
            self?.toastMessage = nil
        }
    }
}
