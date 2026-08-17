import Foundation
import XCTest
@testable import XiaomiRemoteStudio

final class ConfigurationRecoveryTests: XCTestCase {
    @MainActor
    func testCorruptConfigurationIsPreservedBeforeFallingBackToDefaults() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-CorruptConfiguration-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let configurationURL = directory.appendingPathComponent("config.json")
        let corruptData = Data("{ this is not valid JSON".utf8)
        try corruptData.write(to: configurationURL)

        let store = AppStore(
            configurationStore: LocalConfigurationStore(fileURL: configurationURL),
            runtimeServicesEnabled: false
        )

        XCTAssertNotNil(store.configurationLoadWarning)
        XCTAssertTrue(store.backendLog.contains("读取本地配置失败"))
        XCTAssertEqual(try Data(contentsOf: configurationURL), corruptData)

        let recoveryFiles = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix("config-unreadable-") }
        XCTAssertEqual(recoveryFiles.count, 1)
        XCTAssertEqual(try Data(contentsOf: try XCTUnwrap(recoveryFiles.first)), corruptData)
    }

    @MainActor
    func testFutureConfigurationVersionIsRejectedAndPreserved() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-FutureConfiguration-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let configurationURL = directory.appendingPathComponent("config.json")
        var configuration = PersistedConfiguration(assignmentsByProfile: [:])
        configuration.version = PersistedConfiguration.currentVersion + 1
        let encoded = try JSONEncoder().encode(configuration)
        try encoded.write(to: configurationURL)

        let configurationStore = LocalConfigurationStore(fileURL: configurationURL)
        XCTAssertThrowsError(try configurationStore.load()) { error in
            XCTAssertEqual(
                error as? LocalConfigurationStoreError,
                .unsupportedVersion(PersistedConfiguration.currentVersion + 1)
            )
        }

        let store = AppStore(
            configurationStore: configurationStore,
            runtimeServicesEnabled: false
        )
        XCTAssertNotNil(store.configurationLoadWarning)
        XCTAssertEqual(try Data(contentsOf: configurationURL), encoded)
    }

    @MainActor
    func testDeviceBackupRejectsUnsupportedInnerConfigurationVersion() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-BackupVersion-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var configuration = PersistedConfiguration(assignmentsByProfile: [:])
        configuration.version = PersistedConfiguration.currentVersion + 1
        let backup = DeviceConfigurationBackup(
            deviceID: RemoteDevice.remote2Pro.id,
            exportedAt: Date(timeIntervalSince1970: 1_735_689_600),
            configuration: configuration
        )
        let data = try JSONEncoder().encode(backup)
        let store = AppStore(
            configurationStore: LocalConfigurationStore(
                fileURL: directory.appendingPathComponent("config.json")
            ),
            runtimeServicesEnabled: false
        )

        XCTAssertThrowsError(try store.restoreDeviceBackupData(data)) { error in
            XCTAssertEqual(
                error as? DeviceConfigurationBackupError,
                .unsupportedConfigurationVersion(PersistedConfiguration.currentVersion + 1)
            )
        }
    }

    @MainActor
    func testConfigurationWriteFailureIsReportedToTheUser() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-UnwritableConfiguration-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        try Data("not a directory".utf8).write(to: directory)
        let store = AppStore(
            configurationStore: LocalConfigurationStore(
                fileURL: directory.appendingPathComponent("config.json")
            ),
            runtimeServicesEnabled: false
        )

        store.setAppearanceMode(.dark)

        XCTAssertTrue(store.backendLog.contains("保存本地配置失败"))
        XCTAssertEqual(store.toastMessage, "无法保存设置，请检查 MiCoding 的本地数据目录")
    }

    @MainActor
    func testBackupRestoreSaveFailureLeavesLiveConfigurationUntouched() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-TransactionalRestore-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let sourceStore = AppStore(
            configurationStore: LocalConfigurationStore(
                fileURL: root.appendingPathComponent("source/config.json")
            ),
            runtimeServicesEnabled: false
        )
        let okSlot = try XCTUnwrap(RemoteButtonSlot.demoSlots.first(where: { $0.id == "ok" }))
        let copy = try XCTUnwrap(RemoteAction.catalog.first(where: { $0.id == "copy" }))
        sourceStore.selectSlot(okSlot)
        sourceStore.assign(copy, to: okSlot)
        let backupData = try sourceStore.makeDeviceBackupData()

        let parentFile = root.appendingPathComponent("not-a-directory")
        try Data("file blocks child writes".utf8).write(to: parentFile)
        let destinationStore = AppStore(
            configurationStore: LocalConfigurationStore(
                fileURL: parentFile.appendingPathComponent("config.json")
            ),
            runtimeServicesEnabled: false
        )
        let actionBeforeRestore = destinationStore.action(for: okSlot.id)?.id
        let before = try destinationStore.makeDeviceBackupData(exportedAt: .distantPast)

        XCTAssertThrowsError(try destinationStore.restoreDeviceBackupData(backupData)) { error in
            guard case .couldNotSave = error as? DeviceConfigurationBackupError else {
                return XCTFail("恢复写入失败应返回 couldNotSave，实际为 \(error)")
            }
        }

        XCTAssertEqual(destinationStore.action(for: okSlot.id)?.id, actionBeforeRestore)
        let after = try destinationStore.makeDeviceBackupData(exportedAt: .distantPast)
        XCTAssertEqual(before, after, "磁盘写入失败不得部分覆盖内存中的当前配置")
    }
}
