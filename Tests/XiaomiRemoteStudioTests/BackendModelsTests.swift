import AppKit
import XCTest
@testable import XiaomiRemoteStudio

final class BackendModelsTests: XCTestCase {
    func testXiaomiRemoteIdentityAndUsageMap() {
        let settings = BackendSettings()
        XCTAssertEqual(settings.remoteVendorID, 0x2717)
        XCTAssertEqual(settings.remoteProductID, 0x32B8)
        XCTAssertEqual(RemotePhysicalKey.usageMap.count, 13)
        XCTAssertEqual(RemotePhysicalKey.usageMap[0x28], .ok)
        XCTAssertEqual(RemotePhysicalKey.usageMap[0xF1], .back)
        XCTAssertEqual(RemotePhysicalKey.usageMap[0x35], .tv)
    }

    func testPersistedConfigurationRoundTrip() throws {
        let original = PersistedConfiguration(
            settings: BackendSettings(),
            assignmentsByProfile: ["global": ["ok": "play-pause"]],
            holdAssignmentsByProfile: ["global": ["power": "lock"]],
            doubleTapAssignmentsByProfile: [:],
            lastProfileID: "global",
            useDarkAppearance: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PersistedConfiguration.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    @MainActor
    func testSmartActionAssignmentPersistsAndReloads() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("XiaomiRemoteStudioTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let configurationStore = LocalConfigurationStore(
            fileURL: directory.appendingPathComponent("config.json")
        )
        let initialStore = AppStore(configurationStore: configurationStore)
        let action = try XCTUnwrap(RemoteAction.catalog.first(where: { $0.id == "smart-focus" }))
        let slot = try XCTUnwrap(RemoteButtonSlot.demoSlots.first(where: { $0.id == "tv" }))

        initialStore.assign(action, to: slot)

        let reloadedStore = AppStore(configurationStore: configurationStore)
        XCTAssertEqual(reloadedStore.action(for: slot.id)?.id, action.id)
    }

    func testActionCatalogResolvesToExecutableCommands() {
        XCTAssertEqual(ActionCommand.command(for: "spotlight"), .system(.spotlight))
        XCTAssertEqual(ActionCommand.command(for: "volume-up"), .system(.volumeUp))
        XCTAssertEqual(ActionCommand.command(for: "launch-browser"), .openDefaultBrowser)
        XCTAssertEqual(ActionCommand.command(for: "unknown"), .none)

        for action in RemoteAction.catalog {
            XCTAssertNotEqual(
                ActionCommand.command(for: action.id),
                .none,
                "\(action.id) 必须具备可执行命令"
            )
        }
    }

    func testSmartActionsResolveToSequencesAndAppearInTheActionLibrary() {
        for smartAction in SmartAction.samples {
            XCTAssertTrue(RemoteAction.catalog.contains(where: { $0.id == smartAction.actionID }))
            guard case .sequence(let commands) = ActionCommand.command(for: smartAction.actionID) else {
                return XCTFail("\(smartAction.actionID) 应解析为组合动作")
            }
            let executableStepCount = commands.filter {
                if case .delay = $0 { return false }
                return true
            }.count
            XCTAssertEqual(executableStepCount, smartAction.stepCount)
        }
    }

    func testModelAndInterfaceSymbolsResolveToLucideIcons() {
        let symbols =
            AppSection.allCases.map(\.icon)
            + DevicePanel.allCases.map(\.symbol)
            + RemoteButtonSlot.demoSlots.map(\.symbol)
            + RemoteAction.catalog.map(\.symbol)
            + AppProfile.profiles.map(\.symbol)
            + SmartAction.samples.map(\.symbol)
            + Array(AppIconRegistry.interfaceSymbols)

        for symbol in Set(symbols) {
            XCTAssertTrue(
                AppIconRegistry.contains(symbol),
                "缺少 Lucide 图标映射：\(symbol)"
            )
        }
    }

    @MainActor
    func testPreviewHIDEventTravelsThroughTheGesturePipelineToTheExecutor() async {
        let input = PreviewRemoteInputService()
        let executor = RecordingActionExecutor()
        let coordinator = BackendCoordinator(inputService: input, executor: executor)
        coordinator.resolveActionID = { _, slotID, trigger in
            slotID == "ok" && trigger == .tap ? "play-pause" : nil
        }

        coordinator.start()
        input.emit(slotID: "ok", phase: .began)
        input.emit(slotID: "ok", phase: .ended)
        try? await Task.sleep(for: .milliseconds(20))

        XCTAssertEqual(executor.commands, [.system(.playPause)])
        coordinator.stop()
    }

    @MainActor
    func testSettingsReturnsToTheOriginatingSection() {
        let store = AppStore()
        store.selectSection(.automations)
        store.selectSection(.settings)

        XCTAssertEqual(store.activeSection, .settings)

        store.leaveSettings()

        XCTAssertEqual(store.activeSection, .automations)
    }

    @MainActor
    func testDisconnectedDeviceCanBeOpenedForOfflineConfiguration() {
        let store = AppStore()
        store.connectionState = .disconnected

        store.openDevice(.remote2Pro)

        XCTAssertEqual(store.activeDeviceID, RemoteDevice.remote2Pro.id)
        XCTAssertEqual(store.selectedSlotID, "ok")
    }

    @MainActor
    func testGestureEngineResolvesTapImmediatelyWithoutAlternateBinding() {
        let engine = RemoteGestureEngine()
        var resolved: [ResolvedRemoteTrigger] = []
        engine.hasBinding = { _, _ in false }
        engine.onResolvedTrigger = { resolved.append($0) }

        engine.handle(RemoteInputEvent(deviceID: "test", slotID: "ok", phase: .began, timestamp: Date()))
        engine.handle(RemoteInputEvent(deviceID: "test", slotID: "ok", phase: .ended, timestamp: Date()))

        XCTAssertEqual(resolved.map(\.slotID), ["ok"])
        XCTAssertEqual(resolved.map(\.trigger), [.tap])
    }

    @MainActor
    func testGestureEnginePrefersHoldBinding() async {
        let engine = RemoteGestureEngine()
        engine.holdMilliseconds = 10
        var resolved: [ResolvedRemoteTrigger] = []
        engine.hasBinding = { _, trigger in trigger == .hold }
        engine.onResolvedTrigger = { resolved.append($0) }

        engine.handle(RemoteInputEvent(deviceID: "test", slotID: "power", phase: .began, timestamp: Date()))
        try? await Task.sleep(for: .milliseconds(30))
        engine.handle(RemoteInputEvent(deviceID: "test", slotID: "power", phase: .ended, timestamp: Date()))

        XCTAssertEqual(resolved.map(\.trigger), [.hold])
    }

    @MainActor
    func testGestureEngineResolvesDoubleTapWithoutTrailingTap() async {
        let engine = RemoteGestureEngine()
        engine.doubleTapMilliseconds = 30
        var resolved: [ResolvedRemoteTrigger] = []
        engine.hasBinding = { _, trigger in trigger == .doubleTap }
        engine.onResolvedTrigger = { resolved.append($0) }

        engine.handle(RemoteInputEvent(deviceID: "test", slotID: "home", phase: .began, timestamp: Date()))
        engine.handle(RemoteInputEvent(deviceID: "test", slotID: "home", phase: .ended, timestamp: Date()))
        engine.handle(RemoteInputEvent(deviceID: "test", slotID: "home", phase: .began, timestamp: Date()))
        engine.handle(RemoteInputEvent(deviceID: "test", slotID: "home", phase: .ended, timestamp: Date()))
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(resolved.map(\.trigger), [.doubleTap])
    }
}

@MainActor
private final class RecordingActionExecutor: ActionExecuting {
    private(set) var commands: [ActionCommand] = []

    func execute(_ command: ActionCommand) {
        commands.append(command)
    }
}
