import AppKit
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var activeSection: AppSection = .devices
    @Published var activeDeviceID: String?
    @Published var selectedSlotID: String?
    @Published var selectedProfileID = AppProfile.profiles[0].id
    @Published var selectedCategory: ActionCategory?
    @Published var searchText = ""
    @Published var connectionState: DeviceConnectionState = .disconnected
    @Published var pressedSlotID: String?
    @Published var draggedActionID: String?
    @Published var toastMessage: String?
    @Published var useDarkAppearance = false
    @Published var permissions = PermissionService.current()
    @Published var backendLog = "后端尚未启动"

    private var lastContentSection: AppSection = .devices

    private let configurationStore: LocalConfigurationStore
    private var backendSettings = BackendSettings()
    private var holdAssignmentsByProfile: [String: [String: String]] = [:]
    private var doubleTapAssignmentsByProfile: [String: [String: String]] = [:]

    lazy var backendCoordinator: BackendCoordinator = {
        let coordinator = BackendCoordinator()
        coordinator.configure(settings: backendSettings)
        coordinator.resolveActionID = { [weak self] bundleIdentifier, slotID, trigger in
            self?.executionActionID(
                bundleIdentifier: bundleIdentifier,
                slotID: slotID,
                trigger: trigger
            )
        }
        coordinator.onInputEvent = { [weak self] event in
            self?.handlePhysicalInput(event)
        }
        coordinator.onConnectionChanged = { [weak self] connected in
            self?.connectionState = connected ? .connected : .disconnected
        }
        coordinator.onLog = { [weak self] message in
            self?.backendLog = message
        }
        return coordinator
    }()

    private(set) var assignmentsByProfile: [String: [String: String]] = [
        "global": [
            "power": "lock",
            "assistant": "spotlight",
            "ok": "play-pause",
            "back": "mission-control",
            "home": "desktop",
            "volumeUp": "volume-up",
            "volumeDown": "volume-down",
            "tv": "launch-browser",
            "menu": "screenshot"
        ]
    ]

    init(configurationStore: LocalConfigurationStore = LocalConfigurationStore()) {
        self.configurationStore = configurationStore
        if let saved = try? configurationStore.load() {
            assignmentsByProfile = saved.assignmentsByProfile
            holdAssignmentsByProfile = saved.holdAssignmentsByProfile
            doubleTapAssignmentsByProfile = saved.doubleTapAssignmentsByProfile
            backendSettings = saved.settings
            selectedProfileID = AppProfile.profiles.contains(where: { $0.id == saved.lastProfileID })
                ? saved.lastProfileID
                : "global"
            useDarkAppearance = saved.useDarkAppearance
        }
    }

    var preferredColorScheme: ColorScheme? {
        useDarkAppearance ? .dark : .light
    }

    var activeProfile: AppProfile {
        AppProfile.profiles.first(where: { $0.id == selectedProfileID }) ?? AppProfile.profiles[0]
    }

    var selectedSlot: RemoteButtonSlot? {
        guard let selectedSlotID else { return nil }
        return RemoteButtonSlot.demoSlots.first(where: { $0.id == selectedSlotID })
    }

    var draggedAction: RemoteAction? {
        guard let draggedActionID else { return nil }
        return RemoteAction.catalog.first(where: { $0.id == draggedActionID })
    }

    func action(for slotID: String) -> RemoteAction? {
        let actionID = assignmentsByProfile[selectedProfileID]?[slotID]
            ?? assignmentsByProfile["global"]?[slotID]
        return RemoteAction.catalog.first(where: { $0.id == actionID })
    }

    func openDevice(_ device: RemoteDevice) {
        activeDeviceID = device.id
        selectedSlotID = "ok"
        activeSection = .devices
    }

    func closeDevice() {
        activeDeviceID = nil
        selectedSlotID = nil
        draggedActionID = nil
    }

    func selectSection(_ section: AppSection) {
        closeDevice()
        if section == .settings, activeSection != .settings {
            lastContentSection = activeSection
        } else if section != .settings {
            lastContentSection = section
        }
        activeSection = section
    }

    func leaveSettings() {
        closeDevice()
        activeSection = lastContentSection
    }

    func assign(_ action: RemoteAction, to slot: RemoteButtonSlot) {
        guard slot.accepts(action) else {
            draggedActionID = nil
            showToast("“\(action.title)”不能分配到\(slot.name)键")
            return
        }

        var profileAssignments = assignmentsByProfile[selectedProfileID] ?? [:]
        profileAssignments[slot.id] = action.id
        assignmentsByProfile[selectedProfileID] = profileAssignments
        selectedSlotID = slot.id
        draggedActionID = nil
        objectWillChange.send()
        persistConfiguration()
        showToast("已将“\(action.title)”分配到\(slot.name)键")
    }

    func assignToSelectedSlot(_ action: RemoteAction) {
        guard let selectedSlot else {
            showToast("请先在遥控器上选择一个按键")
            return
        }
        assign(action, to: selectedSlot)
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
        refreshPermissions()
        backendCoordinator.start()
    }

    func restartBackend() {
        backendCoordinator.stop()
        startBackend()
    }

    func stopBackend() {
        backendCoordinator.stop()
    }

    func selectProfile(_ profile: AppProfile) {
        selectedProfileID = profile.id
        persistConfiguration()
    }

    func setDarkAppearance(_ enabled: Bool) {
        useDarkAppearance = enabled
        persistConfiguration()
    }

    func refreshPermissions() {
        permissions = PermissionService.current()
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

    func openBluetoothSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.BluetoothSettings",
            "x-apple.systempreferences:com.apple.preferences.Bluetooth"
        ]

        for value in urls {
            if let url = URL(string: value), NSWorkspace.shared.open(url) {
                return
            }
        }
        showToast("请在系统设置中打开蓝牙")
    }

    func runAction(actionID: String, title: String) {
        backendCoordinator.execute(actionID: actionID, source: "手动运行")
        showToast("已运行“\(title)”")
    }

    func testSelectedAction() {
        guard let selectedSlot, let action = action(for: selectedSlot.id) else {
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
        let profileID = AppProfile.profiles.first(where: {
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

        if let profileID, let action = table[profileID]?[slotID] {
            return action
        }
        return table["global"]?[slotID]
    }

    private func handlePhysicalInput(_ event: RemoteInputEvent) {
        selectedSlotID = event.slotID
        switch event.phase {
        case .began:
            pressedSlotID = event.slotID
        case .ended:
            if pressedSlotID == event.slotID {
                pressedSlotID = nil
            }
        }
    }

    private func persistConfiguration() {
        let configuration = PersistedConfiguration(
            settings: backendSettings,
            assignmentsByProfile: assignmentsByProfile,
            holdAssignmentsByProfile: holdAssignmentsByProfile,
            doubleTapAssignmentsByProfile: doubleTapAssignmentsByProfile,
            lastProfileID: selectedProfileID,
            useDarkAppearance: useDarkAppearance
        )
        do {
            try configurationStore.save(configuration)
        } catch {
            backendLog = "保存本地配置失败：\(error.localizedDescription)"
        }
    }

    func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            guard self?.toastMessage == message else { return }
            self?.toastMessage = nil
        }
    }
}
