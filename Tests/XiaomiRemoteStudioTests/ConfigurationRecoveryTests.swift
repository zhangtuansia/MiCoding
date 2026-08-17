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
}
