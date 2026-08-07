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
        lightStore.useDarkAppearance = false
        try render(view: AppShellView(), store: lightStore, name: "home", into: directory)

        lightStore.selectSection(.automations)
        try render(view: AppShellView(), store: lightStore, name: "smart-actions", into: directory)

        let emptySmartActionsStore = makeSnapshotStore()
        emptySmartActionsStore.useDarkAppearance = false
        try render(
            view: SmartActionsView(actions: []),
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

        lightStore.selectedSlotID = "ok"
        lightStore.searchText = "不存在的动作"
        try render(
            view: AppShellView(),
            store: lightStore,
            name: "device-detail-no-results",
            into: directory
        )
        lightStore.searchText = ""

        lightStore.selectedSlotID = "left"
        try render(view: AppShellView(), store: lightStore, name: "device-detail-left", into: directory)
        lightStore.selectedSlotID = "volumeUp"
        try render(view: AppShellView(), store: lightStore, name: "device-detail-volume", into: directory)
        try render(
            view: DeviceDetailView(device: .remote2Pro, initialPanel: .device),
            store: lightStore,
            name: "device-information",
            into: directory
        )

        try render(view: SettingsView(), store: lightStore, name: "settings-general", into: directory)
        try render(
            view: SettingsView(initialSelection: .permissions),
            store: lightStore,
            name: "settings-permissions",
            into: directory
        )
        try render(
            view: SettingsView(initialSelection: .about),
            store: lightStore,
            name: "settings-about",
            into: directory
        )

        let darkStore = makeSnapshotStore()
        darkStore.useDarkAppearance = true
        try render(view: AppShellView(), store: darkStore, name: "home-dark", into: directory)
        darkStore.selectSection(.automations)
        try render(view: AppShellView(), store: darkStore, name: "smart-actions-dark", into: directory)

        let emptySmartActionsDarkStore = makeSnapshotStore()
        emptySmartActionsDarkStore.useDarkAppearance = true
        try render(
            view: SmartActionsView(actions: []),
            store: emptySmartActionsDarkStore,
            name: "smart-actions-empty-dark",
            into: directory
        )

        darkStore.openDevice(.remote2Pro)
        try render(view: AppShellView(), store: darkStore, name: "device-detail-dark", into: directory)
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
    private func makeSnapshotStore() -> AppStore {
        let configurationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-UISnapshots-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("config.json")
        return AppStore(configurationStore: LocalConfigurationStore(fileURL: configurationURL))
    }

    @MainActor
    private func render<Content: View>(
        view: Content,
        store: AppStore,
        name: String,
        into directory: URL
    ) throws {
        let size = CGSize(width: 1_280, height: 820)
        let hostingView = NSHostingView(
            rootView: view
                .environmentObject(store)
                .frame(width: size.width, height: size.height)
                .preferredColorScheme(store.useDarkAppearance ? .dark : .light)
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
        window.orderFront(nil)
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.60))
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
        window.orderOut(nil)
    }
}
