import AppKit
import SwiftUI
import XCTest
@testable import XiaomiRemoteStudio

final class BackendModelsTests: XCTestCase {
    func testLatinDisplayFontUsesTheLighterReferenceWeight() {
        XCTAssertEqual(AppTypography.latinDisplayFontName, "AvenirNext-DemiBold")
        XCTAssertNotNil(NSFont(name: AppTypography.latinDisplayFontName, size: 33))
    }

    @MainActor
    func testLanguageMenuTargetsTheInstalledLocalizationSettingsPane() {
        let urls = AppStore.languageSettingsURLs
        XCTAssertEqual(
            urls.first,
            "x-apple.systempreferences:com.apple.Localization-Settings.extension"
        )
        XCTAssertTrue(
            urls.allSatisfy { URL(string: $0) != nil }
        )
    }

    @MainActor
    func testFlowSetupTargetsInstalledUniversalControlAndHandoffPanes() {
        XCTAssertEqual(
            AppStore.displaysSettingsURLs.first,
            "x-apple.systempreferences:com.apple.Displays-Settings.extension"
        )
        XCTAssertEqual(
            AppStore.handoffSettingsURLs.first,
            "x-apple.systempreferences:com.apple.AirDrop-Handoff-Settings.extension"
        )
        XCTAssertTrue(
            (AppStore.displaysSettingsURLs + AppStore.handoffSettingsURLs)
                .allSatisfy { URL(string: $0) != nil }
        )
    }

    func testDarkControlPaletteKeepsReferenceSurfaceHierarchy() throws {
        let darkCanvas = try XCTUnwrap(
            NSColor(AppTheme.canvas(for: .dark)).usingColorSpace(.deviceRGB)
        )
        let darkPrimarySurface = try XCTUnwrap(
            NSColor(AppTheme.primarySurface(for: .dark)).usingColorSpace(.deviceRGB)
        )
        let darkControlBorder = try XCTUnwrap(
            NSColor(AppTheme.controlBorder(for: .dark)).usingColorSpace(.deviceRGB)
        )

        XCTAssertEqual(darkCanvas.redComponent, 25 / 255, accuracy: 0.001)
        XCTAssertEqual(darkPrimarySurface.redComponent, 0, accuracy: 0.001)
        XCTAssertEqual(darkControlBorder.redComponent, 51 / 255, accuracy: 0.001)
        XCTAssertGreaterThan(darkCanvas.redComponent, darkPrimarySurface.redComponent)
        XCTAssertGreaterThan(darkControlBorder.redComponent, darkCanvas.redComponent)
    }

    func testMainWindowLayoutRejectsOffscreenRestorationAndKeepsReferenceInsets() {
        let screen = NSRect(x: 0, y: 0, width: 1_512, height: 982)
        let referenceFrame = NSRect(x: 80, y: 142, width: 1_180, height: 760)
        let offscreenFrame = NSRect(x: -402, y: 1_300, width: 1_180, height: 760)

        XCTAssertTrue(MainWindowLayoutMetrics.isUsable(frame: referenceFrame, on: [screen]))
        XCTAssertFalse(MainWindowLayoutMetrics.isUsable(frame: offscreenFrame, on: [screen]))
        XCTAssertEqual(
            MainWindowLayoutMetrics.fallbackTopLeft(in: screen),
            NSPoint(x: 80, y: 902)
        )
        XCTAssertEqual(MainWindowLayoutMetrics.contentSize, NSSize(width: 1_180, height: 728))
        XCTAssertEqual(MainWindowLayoutMetrics.frameSize, NSSize(width: 1_180, height: 760))
        XCTAssertTrue(MainWindowLayoutMetrics.styleMask.contains(.closable))
        XCTAssertTrue(MainWindowLayoutMetrics.styleMask.contains(.miniaturizable))
        XCTAssertTrue(MainWindowLayoutMetrics.styleMask.contains(.fullSizeContentView))
        XCTAssertFalse(MainWindowLayoutMetrics.styleMask.contains(.resizable))
    }

    @MainActor
    func testMainMenuMatchesTheReferenceTopLevelStructure() {
        let menu = MiCodingApplicationDelegate().makeMainMenu()

        XCTAssertEqual(menu.items.map(\.title), ["MiCoding", "Edit"])
        XCTAssertEqual(menu.items[0].submenu?.items.last?.title, "退出 MiCoding")
        XCTAssertEqual(
            menu.items[1].submenu?.items.filter { !$0.isSeparatorItem }.map(\.keyEquivalent),
            ["z", "z", "x", "c", "v", "a"]
        )
    }

    @MainActor
    func testUserInitiatedBackendRestartReportsTheRealOutcome() {
        let store = AppStore(
            configurationStore: LocalConfigurationStore(fileURL: nil),
            runtimeServicesEnabled: false
        )

        store.permissions = PermissionSnapshot(
            accessibilityGranted: true,
            inputMonitoringGranted: true
        )
        store.restartBackend(announce: true)
        XCTAssertEqual(store.toastMessage, "MiCoding 输入服务已重新启动")

        store.permissions = PermissionSnapshot(
            accessibilityGranted: true,
            inputMonitoringGranted: false
        )
        store.restartBackend(announce: true)
        XCTAssertEqual(store.toastMessage, "需要输入监控权限后才能启动输入服务")

        store.inputServiceEnabled = false
        store.restartBackend(announce: true)
        XCTAssertEqual(store.toastMessage, "MiCoding 输入服务已停用")
    }

    func testAutomationLibraryLayoutMatchesReferenceGeometry() {
        XCTAssertFalse(AutomationLibraryLayoutMetrics.showsGuideByDefault)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.sidebarTopInset, 255, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.sidebarItemSpacing, 10, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.categorySpacing, 15, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.categoryHorizontalInset, 13, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.toolbarImportYOffset, -2.5, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.toolbarYOffset, -1, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.titleTracking, 1.665, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.titleXOffset, -0.5, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.guideTopInset, 6, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationPlantOffset.width, -94, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationPlantOffset.height, 124, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationOrbOffset.width, 151, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationOrbOffset.height, 92, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationBoxFrontYOffset, 27, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationYOffset, -22, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyCopyTopInset, 30, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationDiamondSide, 156, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationKeyboardSize.width, 93, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationKeyboardSize.height, 126, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationKeyboardOffset.width, -21.5, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationKeyboardOffset.height, 35, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationMouseSize.width, 46, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationMouseSize.height, 72, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationMouseOffset.width, 50, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationMouseOffset.height, 54, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationPlantScale.width, 0.70, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationPlantScale.height, 0.95, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationBoxFlapSize.width, 136, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationBoxFlapSize.height, 46, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationBoxFrontSize.width, 95, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationBoxFrontSize.height, 62.5, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationBoxSideSize.width, 16, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationBoxSideSize.height, 62.5, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationBoxSideOffset.width, 55.5, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationBoxSideOffset.height, 27, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationBoxXOffset, 5, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationPlusXOffset, 111, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationPlusYOffset, -65.5, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.emptyIllustrationOrbSize, 22, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.cardDescriptionTopInset, 8, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.templateFooterHeight, 56, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.templateFooterButtonWidth, 100, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.templateFooterButtonHeight, 48, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.templateFooterButtonXOffset, -1, accuracy: 0.001)
        XCTAssertEqual(AutomationLibraryLayoutMetrics.templateFooterButtonYOffset, -0.5, accuracy: 0.001)
    }

    func testSmartActionEditorMatchesReferenceFixedGeometry() {
        XCTAssertEqual(SmartActionEditorLayoutMetrics.headerHeight, 80, accuracy: 0.001)
        XCTAssertEqual(SmartActionEditorLayoutMetrics.backArrowSize, 24, accuracy: 0.001)
        XCTAssertEqual(
            SmartActionEditorLayoutMetrics.backArrowVerticalScale,
            0.76,
            accuracy: 0.001
        )
        XCTAssertEqual(SmartActionEditorLayoutMetrics.columnWidth, 500, accuracy: 0.001)
        XCTAssertEqual(SmartActionEditorLayoutMetrics.sectionTitleHeight, 48, accuracy: 0.001)
        XCTAssertEqual(SmartActionEditorLayoutMetrics.sectionGap, 32, accuracy: 0.001)
        XCTAssertEqual(SmartActionEditorLayoutMetrics.fieldRowHeight, 56, accuracy: 0.001)
        XCTAssertEqual(SmartActionEditorLayoutMetrics.emptyFieldHeight, 48, accuracy: 0.001)
        XCTAssertEqual(SmartActionEditorLayoutMetrics.sequenceBadgeSize, 40, accuracy: 0.001)
        XCTAssertEqual(SmartActionEditorLayoutMetrics.footerLeadingInset, 33, accuracy: 0.001)
        XCTAssertEqual(SmartActionEditorLayoutMetrics.footerTrailingInset, 25, accuracy: 0.001)
        XCTAssertEqual(SmartActionEditorLayoutMetrics.footerBottomInset, 40, accuracy: 0.001)
        XCTAssertEqual(SmartActionEditorLayoutMetrics.controlWidth, 170, accuracy: 0.001)
        XCTAssertEqual(SmartActionEditorLayoutMetrics.controlHeight, 40, accuracy: 0.001)
    }

    func testActionsRingEditorMatchesReferenceGeometry() {
        XCTAssertEqual(ActionsRingEditorLayoutMetrics.paneWidth, 787)
        XCTAssertEqual(ActionsRingEditorLayoutMetrics.headerHeight, 96)
        XCTAssertEqual(ActionsRingEditorLayoutMetrics.headerTitleTracking, 1.03, accuracy: 0.001)
        XCTAssertEqual(ActionsRingEditorLayoutMetrics.headerTitleVerticalScale, 1.026, accuracy: 0.001)
        XCTAssertEqual(ActionsRingEditorLayoutMetrics.headerTitleYOffset, 1.5, accuracy: 0.001)
        XCTAssertEqual(ActionsRingEditorLayoutMetrics.profileCenterX, 669.5)
        XCTAssertEqual(ActionsRingEditorLayoutMetrics.profileUnderlineWidth, 38.5)
        XCTAssertEqual(ActionsRingEditorLayoutMetrics.addProfileCenterX, 722.5)
        XCTAssertEqual(ActionsRingEditorLayoutMetrics.mediumOrbitRadius, 75)
        XCTAssertEqual(ActionsRingEditorLayoutMetrics.actionLibraryHeaderHeight, 73)
        XCTAssertEqual(ActionsRingEditorLayoutMetrics.actionGroupHeight, 42)
        XCTAssertEqual(ActionsRingEditorLayoutMetrics.actionGroupGap, 8)
        XCTAssertEqual(ActionsRingEditorLayoutMetrics.rootVerticalOffset, -4.35)
        XCTAssertEqual(ActionsRingEditorLayoutMetrics.overviewPreviewBlurRadius, 6)
        XCTAssertEqual(ActionsRingEditorLayoutMetrics.overviewCallToActionFontSize, 14)
    }

    func testDeviceDetailRailMatchesReferencePitch() {
        XCTAssertEqual(
            DevicePanel.allCases.map(\.title),
            ["按钮", "手势与连按", "FLOW", "设置"]
        )
        XCTAssertEqual(HomeToolbarLayoutMetrics.opticalXOffset, -4, accuracy: 0.001)
        XCTAssertEqual(HomeToolbarLayoutMetrics.opticalYOffset, -2, accuracy: 0.001)
        XCTAssertEqual(HomeToolbarLayoutMetrics.greetingWidthScale, 1, accuracy: 0.001)
        XCTAssertEqual(HomeToolbarLayoutMetrics.greetingHeightScale, 1, accuracy: 0.001)
        XCTAssertEqual(HomeToolbarLayoutMetrics.greetingYOffset, 0.5, accuracy: 0.001)
        XCTAssertEqual(HomeToolbarLayoutMetrics.addIconSize, 22, accuracy: 0.001)
        XCTAssertEqual(HomeToolbarLayoutMetrics.addIconXOffset, -2, accuracy: 0.001)
        XCTAssertEqual(HomeToolbarLayoutMetrics.addTextXOffset, -0.5, accuracy: 0.001)
        XCTAssertEqual(HomeToolbarLayoutMetrics.visibleToolbarWidth, 251, accuracy: 0.001)
        XCTAssertEqual(HomeToolbarLayoutMetrics.trailingIconGap, 8, accuracy: 0.001)
        XCTAssertEqual(HomeToolbarLayoutMetrics.settingsIconSize, 22, accuracy: 0.001)
        XCTAssertEqual(HomeToolbarLayoutMetrics.settingsIconXScale, 1.11, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.headerLeadingPadding, 41.5, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.headerClosedYOffset, -37, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.headerOpenYOffset, -40.5, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.headerTrailingContentOpenYOffset, 3.5, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.railLeadingPadding, 47.5, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.railTopPadding, 152.5, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.railBottomPadding, 40, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.connectionTileLeadingPadding, 10.5, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.connectionTileHorizontalScale, 53 / 54, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.connectionTileVerticalScale, 39 / 40, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.railItemTrailingPadding, 12, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.gestureContentXOffset, 0, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.gestureContentYOffset, 0, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.flowContentXOffset, 0, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.flowContentYOffset, 0, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.informationLeadingPadding, 321.625, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.informationContentWidth, 510, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.informationTextWidth, 500, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.informationInlineActionXOffset, -6, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.informationToggleHitWidth, 30, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.informationToggleHitHeight, 22, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.informationWarningYOffset, -9.5, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.informationPostWarningSpacing, 16, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.informationTopCopyYOffset, -7, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.informationRefreshButtonYOffset, -5, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.informationSupportCopyYOffset, 3, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.informationFeatureTitleYOffset, -2.5, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.informationFeatureActionsYOffset, 1.5, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.informationGeneralLabelYOffset, 4, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.informationGeneralRowYOffset, -4.5, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.informationOtherLabelYOffset, -10.5, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.informationBackupTitleYOffset, 4.5, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.informationBackupDescriptionYOffset, 9.5, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.informationBackupActionsYOffset, 12, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.informationViewportExtension, 82, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.informationResetSectionYOffset, 12, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.informationBodyOpticalScale, 1, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.informationTitleOpticalScale, 1, accuracy: 0.001)
        XCTAssertEqual(
            DeviceDetailLayoutMetrics.informationSupportLinkVerticalScale,
            13.5 / 15.5,
            accuracy: 0.001
        )
        XCTAssertEqual(DeviceDetailLayoutMetrics.informationYOffset, -82, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.railRowHeight, 39, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.railRowSpacing, 18, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.railRowPitch, 57, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.applicationPickerHeaderHeight, 114, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.applicationPickerHeaderTopPadding, 28, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.applicationPickerHeaderHorizontalPadding, 32, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.applicationPickerGlobalTopSpacing, 16, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.applicationPickerGlobalBottomSpacing, 8, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.applicationPickerSectionHeight, 48, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.applicationPickerTitleOpticalOffset, 2, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.applicationPickerSectionTextOpticalOffset, 8.5, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.applicationPickerSectionChevronOpticalOffset, -1.5, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.applicationPickerRowTextOpticalOffset, 2, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.globalParameterProfileWidth, 236, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.globalParameterDividerContainerWidth, 48, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.globalParameterAddApplicationWidth, 140, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.globalParameterProfileOpticalXOffset, -4, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.globalParameterAddIconSize, 22.5, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.globalParameterAddIconOpticalYOffset, -0.75, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.globalParameterAddContentOpticalXOffset, -0.5, accuracy: 0.001)
    }

    func testActionLibraryMatchesReferenceOpticalGeometry() {
        XCTAssertEqual(ActionLibraryLayoutMetrics.headerHeight, 70, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.headerLeadingPadding, 30, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.headerTitleOpticalScale, 1.055, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.headerTitleOpticalYOffset, -2, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.searchTextOpticalXOffset, 1, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.searchTextOpticalYOffset, -1.5, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.searchPlaceholderOpacity, 0.45, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.searchIconSize, 18.5, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.searchIconXOffset, 1.5, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.searchIconYOffset, 0.5, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.recommendedTitleOpticalXOffset, 1.5, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.recommendedTitleOpticalYOffset, -1, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.collapsibleTitleOpticalXOffset, 1, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.smartActionsTitleOpticalYOffset, 3.5, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.otherActionsTitleOpticalYOffset, 0, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.categoryTrailingPadding, 27.5, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.categoryChevronSize, 18, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.categoryChevronYOffset, 1, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.compactRowTextOpticalXOffset, 0.5, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.compactRowTextOpticalYOffset, 2, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.compactLatinRowTextOpticalXScale, 1.03, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.compactSelectedRowTextOpticalXOffset, 0.5, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.compactSelectedRowTextOpticalYOffset, -0.5, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.searchTextOpticalXScale, 0.99, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.recommendedTitleOpticalXScale, 1, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.smartActionsTitleOpticalXScale, 0.96, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.smartActionsTitleOpticalYScale, 0.955, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.actionsRingDetailHorizontalPadding, 13, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.actionsRingConfigurationTopPadding, 26, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.actionsRingDescriptionXOffset, -3.5, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.actionsRingDescriptionYOffset, 2.5, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.actionsRingConfigurationXOffset, -3.5, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.shortcutRecorderTopPadding, 20, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.shortcutRecorderDetailHeight, 188, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.shortcutRecorderRowHeight, 236, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.applicationPickerDetailHeight, 140, accuracy: 0.001)
        XCTAssertEqual(ActionLibraryLayoutMetrics.applicationPickerRowHeight, 188, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.trailingPanelWidth, 1_180 / 3, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.trailingPanelShadowOpacity, 0.06, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.trailingPanelShadowRadius, 24, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.trailingPanelShadowX, 5, accuracy: 0.001)
        XCTAssertEqual(DeviceDetailLayoutMetrics.trailingPanelShadowY, 5, accuracy: 0.001)
    }

    func testSettingsLayoutMatchesReferenceColumnGeometry() {
        let navigationWidth = SettingsLayoutMetrics.navigationWidth(for: 1_180)
        XCTAssertEqual(navigationWidth, 403, accuracy: 0.001)
        XCTAssertEqual(
            navigationWidth + SettingsLayoutMetrics.contentLeadingPadding,
            462,
            accuracy: 0.001,
            "设置内容的布局原点必须保持在参考应用的 462 pt 基准线上"
        )
        XCTAssertEqual(SettingsLayoutMetrics.contentTopPadding, 32.5, accuracy: 0.001)
        XCTAssertEqual(SettingsLayoutMetrics.navigationTopPadding, 25, accuracy: 0.001)
        XCTAssertEqual(SettingsLayoutMetrics.navigationListTopPadding, 152.5, accuracy: 0.001)
        XCTAssertEqual(SettingsLayoutMetrics.navigationBackOpticalXOffset, -7.5, accuracy: 0.001)
        XCTAssertEqual(SettingsLayoutMetrics.navigationTitleOpticalYOffset, 3.5, accuracy: 0.001)
        XCTAssertEqual(SettingsLayoutMetrics.textLinkOpticalXScale, 1.075, accuracy: 0.001)
        XCTAssertEqual(SettingsLayoutMetrics.textLinkOpticalYOffset, -4, accuracy: 0.001)
        XCTAssertEqual(SettingsLayoutMetrics.pageTitleOpticalWidthScale, 1, accuracy: 0.001)
        XCTAssertEqual(SettingsLayoutMetrics.pageTitleOpticalHeightScale, 1, accuracy: 0.001)
        XCTAssertEqual(SettingsLayoutMetrics.pageTitleOpticalYOffset, -2, accuracy: 0.001)
        XCTAssertEqual(SettingsLayoutMetrics.servicePageTitleOpticalYOffset, 0, accuracy: 0.001)
        XCTAssertEqual(SettingsLayoutMetrics.sectionTitleOpticalWidthScale, 1.008, accuracy: 0.001)
        XCTAssertEqual(SettingsLayoutMetrics.sectionTitleOpticalHeightScale, 0.97, accuracy: 0.001)
        XCTAssertEqual(SettingsLayoutMetrics.themeSectionTitleOpticalYOffset, 1, accuracy: 0.001)
    }

    func testActionLibraryHeaderMatchesReferenceVerticalGeometry() {
        XCTAssertEqual(ActionLibraryLayoutMetrics.headerHeight, 70, accuracy: 0.001)
    }

    func testFeatureOverviewIntroMatchesReferenceVerticalGeometry() {
        XCTAssertEqual(FeatureOverviewMetrics.introProductSize.height, 293, accuracy: 0.001)
        XCTAssertEqual(
            FeatureOverviewMetrics.introProductCenterY(for: 728),
            190.18,
            accuracy: 0.001
        )
        XCTAssertEqual(
            FeatureOverviewMetrics.introCopyCenterY(for: 728),
            541.72,
            accuracy: 0.001
        )
        XCTAssertEqual(FeatureOverviewMetrics.tourDeviceCenter.x, 330, accuracy: 0.001)
        XCTAssertEqual(FeatureOverviewMetrics.tourDeviceCenter.y, 349, accuracy: 0.001)
        XCTAssertEqual(FeatureOverviewMetrics.tourPanelCenter.x, 879, accuracy: 0.001)
        XCTAssertEqual(FeatureOverviewMetrics.tourPanelCenter.y, 352.5, accuracy: 0.001)
        XCTAssertEqual(FeatureOverviewMetrics.tourSkipCenter.x, 1_117, accuracy: 0.001)
        XCTAssertEqual(FeatureOverviewMetrics.tourSkipCenter.y, 48.5, accuracy: 0.001)
        XCTAssertEqual(FeatureOverviewMetrics.tourPanelSize.width, 390, accuracy: 0.001)
        XCTAssertEqual(FeatureOverviewMetrics.tourPanelSize.height, 192, accuracy: 0.001)
        XCTAssertEqual(FeatureOverviewMetrics.tourPanelHeaderHeight, 77, accuracy: 0.001)
        XCTAssertEqual(FeatureOverviewMetrics.tourSliderWidth, 323, accuracy: 0.001)
        XCTAssertEqual(FeatureOverviewMetrics.tourSliderHeight, 16, accuracy: 0.001)
    }

    func testXiaomiRemoteIdentityAndUsageMap() {
        let settings = BackendSettings()
        XCTAssertEqual(settings.remoteVendorID, 0x2717)
        XCTAssertEqual(settings.remoteProductID, 0x32B8)
        XCTAssertEqual(RemotePhysicalKey.usageMap.count, 13)
        XCTAssertEqual(RemotePhysicalKey.usageMap[0x28], .ok)
        XCTAssertEqual(RemotePhysicalKey.usageMap[0xF1], .back)
        XCTAssertEqual(RemotePhysicalKey.usageMap[0x35], .tv)
        XCTAssertEqual(
            Set(RemoteButtonSlot.demoSlots.map(\.id)),
            Set(RemotePhysicalKey.allCases.map(\.slotID)),
            "UI 热点与真实 HID 按键必须使用同一组 ID"
        )
    }

    @MainActor
    func testFeatureOverviewTracksPhysicalKeysAndSuppressesAssignedActions() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-FeatureOverviewTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = AppStore(configurationStore: LocalConfigurationStore(
            fileURL: directory.appendingPathComponent("config.json")
        ))
        store.openDevice(.remote2Pro)
        store.showFeatureOverview()

        XCTAssertTrue(store.showsFeatureOverview)
        XCTAssertFalse(store.featureOverviewStartsInKeyTest)
        XCTAssertTrue(store.detectedPhysicalKeyIDs.isEmpty)
        XCTAssertTrue(store.unknownPhysicalUsages.isEmpty)
        XCTAssertNil(store.backendCoordinator.resolveActionID?(nil, "power", .tap))

        store.backendCoordinator.onUnknownUsage?(0xAB, true)
        XCTAssertEqual(store.unknownPhysicalUsages, [0xAB])
        XCTAssertNotNil(store.lastUnknownPhysicalUsageDate)

        store.backendCoordinator.onUnknownUsage?(0xAB, false)
        XCTAssertEqual(store.unknownPhysicalUsages, [0xAB])

        store.backendCoordinator.onInputEvent?(
            RemoteInputEvent(
                deviceID: RemoteDevice.remote2Pro.id,
                slotID: "power",
                phase: .began,
                timestamp: Date()
            )
        )
        XCTAssertEqual(store.detectedPhysicalKeyIDs, ["power"])
        XCTAssertEqual(store.pressedSlotID, "power")

        store.showFeatureOverview()
        XCTAssertTrue(store.detectedPhysicalKeyIDs.isEmpty)
        XCTAssertTrue(store.unknownPhysicalUsages.isEmpty)
        XCTAssertNil(store.pressedSlotID)

        store.backendCoordinator.onInputEvent?(
            RemoteInputEvent(
                deviceID: RemoteDevice.remote2Pro.id,
                slotID: "power",
                phase: .ended,
                timestamp: Date()
            )
        )
        store.dismissFeatureOverview()

        XCTAssertFalse(store.showsFeatureOverview)
        XCTAssertNil(store.pressedSlotID)
        XCTAssertNil(store.selectedSlotID)
        XCTAssertEqual(store.backendCoordinator.resolveActionID?(nil, "power", .tap), "lock")
    }

    @MainActor
    func testPhysicalKeyTestUsesDedicatedOverviewRoute() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-PhysicalKeyTestTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = AppStore(configurationStore: LocalConfigurationStore(
            fileURL: directory.appendingPathComponent("config.json")
        ))
        store.showPhysicalKeyTest()

        XCTAssertTrue(store.showsFeatureOverview)
        XCTAssertTrue(store.featureOverviewStartsInKeyTest)
        XCTAssertNil(store.backendCoordinator.resolveActionID?(nil, "power", .tap))

        store.dismissFeatureOverview()

        XCTAssertFalse(store.showsFeatureOverview)
        XCTAssertFalse(store.featureOverviewStartsInKeyTest)
    }

    @MainActor
    func testAIWorkflowToolbarEntryRoutesToAITemplates() {
        let store = AppStore(runtimeServicesEnabled: false)

        store.toggleAIPromptNotice()
        XCTAssertTrue(store.showsAIPromptNotice)

        store.showAIWorkflowTemplates()

        XCTAssertEqual(store.activeSection, .automations)
        XCTAssertFalse(store.showsAIPromptNotice)
        XCTAssertEqual(store.requestedAutomationCategory, "AI")
        XCTAssertEqual(store.consumeRequestedAutomationCategory(), "AI")
        XCTAssertNil(store.requestedAutomationCategory)

        store.selectSection(.automations)
        XCTAssertNil(store.consumeRequestedAutomationCategory())
    }

    func testBluetoothBatteryServiceParsesConnectedDeviceLevel() throws {
        let data = try XCTUnwrap(
            """
            {
              "SPBluetoothDataType": [{
                "device_connected": [{
                  "小米蓝牙语音遥控器": {
                    "device_batteryLevelMain": "73%",
                    "device_firmwareVersion": "2671",
                    "device_services": "0x400000 < BLE >"
                  }
                }]
              }]
            }
            """.data(using: .utf8)
        )

        XCTAssertEqual(
            BluetoothBatteryService.level(in: data, deviceName: "小米蓝牙语音遥控器"),
            73
        )
        XCTAssertEqual(
            BluetoothBatteryService.snapshot(in: data, deviceName: "小米蓝牙语音遥控器"),
            BluetoothDeviceSnapshot(batteryLevel: 73, firmwareVersion: "2671")
        )
        XCTAssertNil(BluetoothBatteryService.level(in: data, deviceName: "MX Master 3"))
    }

    func testBluetoothBatteryServiceMatchesRenamedRemoteByIdentifiers() throws {
        let data = try XCTUnwrap(
            """
            {
              "SPBluetoothDataType": [{
                "device_connected": [{
                  "客厅遥控器": {
                    "device_batteryLevelMain": "41%",
                    "device_firmwareVersion": "2671",
                    "device_productID": "0x32B8",
                    "device_vendorID": "0x2717"
                  }
                }]
              }]
            }
            """.data(using: .utf8)
        )

        XCTAssertEqual(
            BluetoothBatteryService.snapshot(
                in: data,
                deviceName: "小米蓝牙语音遥控器",
                vendorID: 0x2717,
                productID: 0x32B8
            ),
            BluetoothDeviceSnapshot(batteryLevel: 41, firmwareVersion: "2671")
        )
        XCTAssertNil(
            BluetoothBatteryService.snapshot(
                in: data,
                deviceName: "小米蓝牙语音遥控器",
                vendorID: 0x046D,
                productID: 0xB023
            )
        )
    }

    func testBluetoothBatteryServiceAcceptsNumericAndAlternateBatteryFields() throws {
        let numericData = try XCTUnwrap(
            """
            {
              "小米蓝牙语音遥控器": {
                "device_batteryLevelMain": 86,
                "device_firmwareVersion": 2671
              }
            }
            """.data(using: .utf8)
        )
        XCTAssertEqual(
            BluetoothBatteryService.snapshot(
                in: numericData,
                deviceName: "小米蓝牙语音遥控器"
            ),
            BluetoothDeviceSnapshot(batteryLevel: 86, firmwareVersion: "2671")
        )

        let alternateData = try XCTUnwrap(
            """
            {
              "小米蓝牙语音遥控器": {
                "device_batteryPercent": "0x49"
              }
            }
            """.data(using: .utf8)
        )
        XCTAssertEqual(
            BluetoothBatteryService.level(
                in: alternateData,
                deviceName: "小米蓝牙语音遥控器"
            ),
            73
        )
    }

    func testSoftwareUpdateServiceParsesReleaseAndComparesVersions() throws {
        let data = try XCTUnwrap(
            """
            {
              "tag_name": "v0.3.1",
              "html_url": "https://github.com/zhangtuansia/MiCoding/releases/tag/v0.3.1"
            }
            """.data(using: .utf8)
        )
        let release = try SoftwareUpdateService.parseLatestRelease(in: data)

        XCTAssertEqual(release.version, "0.3.1")
        XCTAssertEqual(
            release.pageURL.absoluteString,
            "https://github.com/zhangtuansia/MiCoding/releases/tag/v0.3.1"
        )
        XCTAssertTrue(SoftwareUpdateService.isNewer("0.3.1", than: "0.2.9"))
        XCTAssertTrue(SoftwareUpdateService.isNewer("v1.0", than: "0.9.99"))
        XCTAssertFalse(SoftwareUpdateService.isNewer("0.2.0", than: "0.2"))
        XCTAssertFalse(SoftwareUpdateService.isNewer("0.1.9", than: "0.2.0"))
    }

    @MainActor
    func testInjectedRuntimeSnapshotStaysDeterministicWhenServicesAreDisabled() {
        let configurationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-RuntimeSnapshot-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: configurationURL) }

        let store = AppStore(
            configurationStore: LocalConfigurationStore(fileURL: configurationURL),
            runtimeServicesEnabled: false,
            initialDeviceSnapshot: BluetoothDeviceSnapshot(
                batteryLevel: 63,
                firmwareVersion: "test-firmware"
            )
        )

        store.startBackend()
        store.refreshRuntimeState()
        store.refreshDeviceInformation()

        XCTAssertTrue(store.devicePresent)
        XCTAssertEqual(store.connectionState, .connected)
        XCTAssertEqual(store.batteryLevel, 63)
        XCTAssertEqual(store.firmwareVersion, "test-firmware")
    }

    func testHIDStateTrackerCreatesReleaseFromEmptyArrayReport() {
        var tracker = RemoteHIDStateTracker()

        XCTAssertEqual(
            tracker.update(with: [0x28]),
            [RemoteHIDStateChange(usage: 0x28, isDown: true)]
        )
        XCTAssertEqual(
            tracker.update(with: []),
            [RemoteHIDStateChange(usage: 0x28, isDown: false)]
        )
    }

    func testHIDStateTrackerDiffsMultiKeyReportsWithoutRepeats() {
        var tracker = RemoteHIDStateTracker()

        _ = tracker.update(with: [0x28, 0x52])
        XCTAssertEqual(tracker.update(with: [0x28, 0x52]), [])
        XCTAssertEqual(
            tracker.update(with: [0x52, 0x51]),
            [
                RemoteHIDStateChange(usage: 0x28, isDown: false),
                RemoteHIDStateChange(usage: 0x51, isDown: true)
            ]
        )
    }

    func testRawHIDReportParserReadsThreeLittleEndianKeyboardSlots() {
        XCTAssertEqual(
            RemoteHIDReportParser.keyboardUsages(
                reportID: 1,
                bytes: [0x28, 0x00, 0xF1, 0x00, 0xFF, 0xFF]
            ),
            [0x28, 0xF1]
        )
        XCTAssertEqual(
            RemoteHIDReportParser.keyboardUsages(
                reportID: 1,
                bytes: [0x01, 0x52, 0x00, 0x00, 0x00, 0xFF, 0xFF]
            ),
            [0x52],
            "兼容回调缓冲区仍包含 report ID 的系统版本"
        )
    }

    func testHIDValueParserReadsUsageFromXiaomiKeyboardArrayValue() {
        XCTAssertEqual(
            RemoteHIDReportParser.keyboardUsage(
                elementUsage: UInt32.max,
                integerValue: 0xF1
            ),
            0xF1,
            "小米遥控器的数组元素把真实按键 usage 放在 value 中"
        )
        XCTAssertNil(
            RemoteHIDReportParser.keyboardUsage(
                elementUsage: UInt32.max,
                integerValue: -1
            ),
            "空数组槽由 macOS 表示为 -1"
        )
        XCTAssertNil(
            RemoteHIDReportParser.keyboardUsage(
                elementUsage: UInt32.max,
                integerValue: 0
            )
        )
    }

    func testHIDValueParserKeepsConventionalVariableKeyboardElements() {
        XCTAssertEqual(
            RemoteHIDReportParser.keyboardUsage(elementUsage: 0x28, integerValue: 1),
            0x28
        )
        XCTAssertNil(
            RemoteHIDReportParser.keyboardUsage(elementUsage: 0x28, integerValue: 0)
        )
    }

    func testHIDValueParserReadsAllThreeArraySlots() {
        XCTAssertEqual(
            RemoteHIDReportParser.keyboardArrayUsages(
                bytes: [0x52, 0x00, 0x28, 0x00, 0xF1, 0x00]
            ),
            [0x52, 0x28, 0xF1]
        )
        XCTAssertEqual(
            RemoteHIDReportParser.keyboardArrayUsages(
                bytes: [0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00]
            ),
            []
        )
        XCTAssertNil(
            RemoteHIDReportParser.keyboardArrayUsages(bytes: [0x28, 0x00])
        )
    }

    func testRawHIDReportParserIgnoresVoiceReportsAndRejectsShortPayloads() {
        XCTAssertNil(
            RemoteHIDReportParser.keyboardUsages(
                reportID: 6,
                bytes: Array(repeating: 0x28, count: 120)
            )
        )
        XCTAssertNil(
            RemoteHIDReportParser.keyboardUsages(
                reportID: 6,
                bytes: [0x01, 0x28, 0x00, 0x00, 0x00, 0x00, 0x00]
            ),
            "语音载荷以 0x01 开头时也不能被误认成键盘 report 1"
        )
        XCTAssertEqual(
            RemoteHIDReportParser.keyboardUsages(
                reportID: 0,
                bytes: [0x01, 0x28, 0x00, 0x00, 0x00, 0x00, 0x00]
            ),
            [0x28],
            "兼容回调 ID 为 0、缓冲区自带 report ID 的系统路径"
        )
        XCTAssertNil(
            RemoteHIDReportParser.keyboardUsages(reportID: 1, bytes: [0x28, 0x00])
        )
        XCTAssertEqual(
            RemoteHIDReportParser.keyboardUsages(
                reportID: 1,
                bytes: [0, 0, 0xFF, 0xFF, 0, 0]
            ),
            []
        )
    }

    func testDeviceKeyRemapperParsesAndScopesMappings() throws {
        let output = """
        RegistryID  Key  Value
        1000ca40b UserKeyMapping (
          {
            HIDKeyboardModifierMappingDst = 30064771184;
            HIDKeyboardModifierMappingSrc = 30064771125;
          }
        )
        """
        let parsed = try XCTUnwrap(DeviceKeyRemapper.parseUserKeyMapping(output))
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].source, 30_064_771_125)
        XCTAssertEqual(parsed[0].destination, 30_064_771_184)

        XCTAssertEqual(DeviceKeyRemapper.ownMappings.count, 12)
        XCTAssertFalse(DeviceKeyRemapper.ownMappings.contains(where: {
            $0.source == 0x700000000 + 0xF1
        }), "0xF1 超出 hidutil 支持范围，继续由 IOHID 直接读取")
        XCTAssertEqual(Set(DeviceKeyRemapper.ownMappings.map(\.destination)).count, 12)
        XCTAssertEqual(
            DeviceKeyRemapper.physicalKey(forRelayKeyCode: 79),
            .ok
        )
        XCTAssertEqual(
            DeviceKeyRemapper.physicalKey(forRelayKeyCode: 78),
            .voice
        )
    }

    func testDeviceKeyRemapperReappliesMappingAfterReconnect() {
        var setCount = 0
        let remapper = DeviceKeyRemapper(
            hidutilRunner: { arguments, _ in
                if arguments.contains("--get") {
                    return (true, "RegistryID  Key  Value\n1000dab81 UserKeyMapping (null)\n")
                }
                if arguments.contains("--set") {
                    setCount += 1
                    return (true, "")
                }
                return (false, "")
            },
            startsCleanupMonitor: false
        )

        XCTAssertTrue(remapper.install())
        XCTAssertTrue(remapper.install(), "重连回调必须重新写入新建 HID 服务的映射")
        XCTAssertEqual(setCount, 2)
    }

    @MainActor
    func testStoppingInputRestoresMappingAndIgnoresLateReconnectCallback() async {
        let input = PreviewRemoteInputService()
        let remapper = RecordingDeviceKeyRemapper()
        let coordinator = BackendCoordinator(
            inputService: input,
            keyRemapper: remapper
        )

        coordinator.start()
        await Task.yield()
        XCTAssertGreaterThanOrEqual(remapper.installCount, 1)

        coordinator.stopInput()
        let installsAfterStop = remapper.installCount
        XCTAssertEqual(remapper.uninstallCount, 1)

        input.onConnectionChanged?(true)
        await Task.yield()
        XCTAssertEqual(
            remapper.installCount,
            installsAfterStop,
            "监听已停止后到达的重连回调不能重新吞掉设备按键"
        )
    }

    @MainActor
    func testKeyMappingWaitsForConfirmedHIDConnection() async {
        let input = ControllableRemoteInputService()
        let remapper = RecordingDeviceKeyRemapper()
        let coordinator = BackendCoordinator(
            inputService: input,
            keyRemapper: remapper
        )

        coordinator.start()
        await Task.yield()
        XCTAssertEqual(
            remapper.installCount,
            0,
            "设备尚未被 HID 管理器枚举时不能先吞掉原始按键"
        )

        input.emitConnection(true)
        await Task.yield()
        XCTAssertEqual(remapper.installCount, 1)

        coordinator.stopInput()
        XCTAssertEqual(remapper.uninstallCount, 1)
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
    func testLegacyDefaultMapGainsDirectionalArrowActionsWithoutChangingClearedMaps() throws {
        let legacyDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-DirectionalMigration-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: legacyDirectory) }
        let legacyStore = LocalConfigurationStore(
            fileURL: legacyDirectory.appendingPathComponent("config.json")
        )
        try legacyStore.save(
            PersistedConfiguration(
                assignmentsByProfile: [
                    "global": [
                        "power": "lock",
                        "voice": "spotlight",
                        "ok": "play-pause",
                        "back": "browser-back",
                        "home": "desktop",
                        "volumeUp": "volume-up",
                        "volumeDown": "volume-down",
                        "tv": "launch-browser",
                        "menu": "screenshot"
                    ]
                ]
            )
        )

        let migrated = AppStore(
            configurationStore: legacyStore,
            runtimeServicesEnabled: false
        )
        XCTAssertEqual(migrated.action(for: "up")?.id, "arrow-up")
        XCTAssertEqual(migrated.action(for: "down")?.id, "arrow-down")
        XCTAssertEqual(migrated.action(for: "left")?.id, "arrow-left")
        XCTAssertEqual(migrated.action(for: "right")?.id, "arrow-right")

        let clearedDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-DirectionalCleared-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: clearedDirectory) }
        let clearedStore = LocalConfigurationStore(
            fileURL: clearedDirectory.appendingPathComponent("config.json")
        )
        try clearedStore.save(PersistedConfiguration(assignmentsByProfile: ["global": [:]]))
        let cleared = AppStore(
            configurationStore: clearedStore,
            runtimeServicesEnabled: false
        )
        XCTAssertNil(cleared.action(for: "left"))
    }

    func testDirectionalActionsResolveToNativeMacArrowKeyCodes() {
        XCTAssertEqual(ActionCommand.command(for: "arrow-up"), .keyStroke(keyCode: 126, flags: 0))
        XCTAssertEqual(ActionCommand.command(for: "arrow-down"), .keyStroke(keyCode: 125, flags: 0))
        XCTAssertEqual(ActionCommand.command(for: "arrow-left"), .keyStroke(keyCode: 123, flags: 0))
        XCTAssertEqual(ActionCommand.command(for: "arrow-right"), .keyStroke(keyCode: 124, flags: 0))
    }

    @MainActor
    func testDeviceConfigurationBackupRestoresAndPersistsDeviceState() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-DeviceBackupTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let configurationStore = LocalConfigurationStore(
            fileURL: directory.appendingPathComponent("config.json")
        )
        let store = AppStore(
            configurationStore: configurationStore,
            runtimeServicesEnabled: false
        )
        let okSlot = try XCTUnwrap(RemoteButtonSlot.demoSlots.first(where: { $0.id == "ok" }))
        let copyAction = try XCTUnwrap(RemoteAction.catalog.first(where: { $0.id == "copy" }))
        let lockAction = try XCTUnwrap(RemoteAction.catalog.first(where: { $0.id == "lock" }))

        store.selectSlot(okSlot)
        store.assign(copyAction, to: okSlot)
        store.setHoldMilliseconds(725)
        let action = SmartAction(
            id: "backup-action",
            actionID: "custom-smart-backup",
            title: "备份中的操作",
            subtitle: "1 个步骤",
            symbol: "keyboard",
            tint: .purple,
            stepCount: 1,
            stepActionIDs: ["copy"]
        )
        store.addSmartAction(action)

        let exportedAt = Date(timeIntervalSince1970: 1_735_689_600)
        let backupData = try store.makeDeviceBackupData(exportedAt: exportedAt)
        let backup = try JSONDecoder().decode(DeviceConfigurationBackup.self, from: backupData)
        XCTAssertEqual(backup.deviceID, RemoteDevice.remote2Pro.id)
        XCTAssertEqual(backup.exportedAt, exportedAt)

        store.assign(lockAction, to: okSlot)
        store.setHoldMilliseconds(400)
        try store.restoreDeviceBackupData(backupData)

        XCTAssertEqual(store.action(for: "ok")?.id, "copy")
        XCTAssertEqual(store.holdMilliseconds, 725)
        XCTAssertTrue(store.smartActions.contains(where: { $0.actionID == action.actionID }))

        let reloaded = AppStore(
            configurationStore: configurationStore,
            runtimeServicesEnabled: false
        )
        XCTAssertEqual(reloaded.action(for: "ok")?.id, "copy")
        XCTAssertEqual(reloaded.holdMilliseconds, 725)
        XCTAssertTrue(reloaded.smartActions.contains(where: { $0.actionID == action.actionID }))
    }

    @MainActor
    func testAppearanceServiceAndNotificationPreferencesPersistAndReload() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-PreferenceTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let configurationStore = LocalConfigurationStore(
            fileURL: directory.appendingPathComponent("config.json")
        )
        let store = AppStore(configurationStore: configurationStore)
        store.setAppearanceMode(.dark)
        store.setAutomaticUpdates(false)
        store.setInputServiceEnabled(false)
        store.setActionNotifications(false)
        store.setPermissionReminders(false)
        store.setExperienceRecommendations(false)
        store.setConnectionNotifications(false)
        store.setLowBatteryNotifications(false)

        let restored = AppStore(configurationStore: configurationStore)
        XCTAssertEqual(restored.appearanceMode, .dark)
        XCTAssertFalse(restored.automaticUpdatesEnabled)
        XCTAssertFalse(restored.inputServiceEnabled)
        XCTAssertFalse(restored.showActionNotifications)
        XCTAssertFalse(restored.showPermissionReminders)
        XCTAssertFalse(restored.showExperienceRecommendations)
        XCTAssertFalse(restored.showConnectionNotifications)
        XCTAssertFalse(restored.showLowBatteryNotifications)
    }

    @MainActor
    func testLowBatteryWarningOnlyFiresWhenEnteringThreshold() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-LowBatteryTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = AppStore(
            configurationStore: LocalConfigurationStore(
                fileURL: directory.appendingPathComponent("config.json")
            ),
            runtimeServicesEnabled: false
        )

        XCTAssertNil(store.recordBatteryLevel(21))
        XCTAssertEqual(store.recordBatteryLevel(20), "遥控器电量低：20%")
        XCTAssertNil(store.recordBatteryLevel(19), "低电量区间内刷新不能重复提醒")
        XCTAssertNil(store.recordBatteryLevel(55), "恢复电量只应重新启用阈值检测")
        XCTAssertEqual(store.recordBatteryLevel(18), "遥控器电量低：18%")

        store.setLowBatteryNotifications(false)
        XCTAssertNil(store.recordBatteryLevel(55))
        XCTAssertNil(store.recordBatteryLevel(15), "关闭通知后不得生成提醒")
    }

    @MainActor
    func testApplicationProfileRemovalPersistsAndCanBeReadded() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-ProfileTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let configurationStore = LocalConfigurationStore(
            fileURL: directory.appendingPathComponent("config.json")
        )
        let removableProfile = try XCTUnwrap(
            AppProfile.profiles.first(where: { $0.id == "chrome" })
        )
        let store = AppStore(configurationStore: configurationStore)

        store.selectProfile(removableProfile)
        store.removeApplicationProfile(removableProfile)

        XCTAssertEqual(store.selectedProfileID, "global")
        XCTAssertFalse(store.profiles.contains(where: { $0.id == removableProfile.id }))

        let removedState = AppStore(configurationStore: configurationStore)
        XCTAssertFalse(removedState.profiles.contains(where: { $0.id == removableProfile.id }))

        removedState.addApplicationProfile(removableProfile)
        let readdedState = AppStore(configurationStore: configurationStore)
        XCTAssertTrue(readdedState.profiles.contains(where: { $0.id == removableProfile.id }))
        XCTAssertEqual(readdedState.selectedProfileID, removableProfile.id)
    }

    @MainActor
    func testApplicationPickerTogglesAProfileWithoutClosingThePanel() {
        let store = AppStore(configurationStore: LocalConfigurationStore(fileURL: nil))
        let profile = AppProfile(
            id: "com.example.profile-test",
            title: "Profile Test",
            subtitle: "应用专属配置",
            symbol: "app.dashed",
            tint: .gray,
            bundleIdentifier: "com.example.profile-test"
        )

        store.openDevice(.remote2Pro)
        store.showApplicationPicker()
        store.toggleApplicationProfile(profile)

        XCTAssertTrue(store.showsApplicationPicker)
        XCTAssertTrue(store.isApplicationProfileEnabled(profile))

        store.toggleApplicationProfile(profile)
        XCTAssertTrue(store.showsApplicationPicker)
        XCTAssertFalse(store.isApplicationProfileEnabled(profile))
    }

    @MainActor
    func testResetDeviceConfigurationClearsEveryTriggerAndPersists() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-DeviceResetTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let configurationStore = LocalConfigurationStore(
            fileURL: directory.appendingPathComponent("config.json")
        )
        let store = AppStore(configurationStore: configurationStore)
        let slot = try XCTUnwrap(RemoteButtonSlot.demoSlots.first(where: { $0.id == "ok" }))
        let action = try XCTUnwrap(RemoteAction.catalog.first(where: { $0.id == "copy" }))

        for trigger in RemoteTrigger.allCases {
            store.selectedTrigger = trigger
            store.assign(action, to: slot)
        }
        store.resetDeviceConfiguration()

        for trigger in RemoteTrigger.allCases {
            XCTAssertNil(store.action(for: slot.id, trigger: trigger))
        }
        XCTAssertEqual(store.selectedProfileID, "global")
        XCTAssertEqual(store.selectedTrigger, .tap)

        let restored = AppStore(configurationStore: configurationStore)
        for trigger in RemoteTrigger.allCases {
            XCTAssertNil(restored.action(for: slot.id, trigger: trigger))
        }
    }

    @MainActor
    func testTriggerSelectionPersistsWhileConfiguringMultipleButtons() throws {
        let store = AppStore(configurationStore: LocalConfigurationStore(fileURL: nil))
        let power = try XCTUnwrap(RemoteButtonSlot.demoSlots.first(where: { $0.id == "power" }))
        let voice = try XCTUnwrap(RemoteButtonSlot.demoSlots.first(where: { $0.id == "voice" }))

        store.selectSlot(power)
        store.selectedTrigger = .hold
        store.selectSlot(voice)

        XCTAssertEqual(store.selectedSlotID, voice.id)
        XCTAssertEqual(store.selectedTrigger, .hold)

        store.closeActionLibrary()
        XCTAssertEqual(store.selectedTrigger, .tap)
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

    @MainActor
    func testSmartActionAssignmentFlowCarriesActionToChosenButton() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCodingPendingSmartAction-\(UUID().uuidString)", isDirectory: true)
        let configurationURL = directory.appendingPathComponent("config.json")
        let store = AppStore(configurationStore: LocalConfigurationStore(fileURL: configurationURL))

        store.beginAssigningSmartAction(.samples[1])
        XCTAssertEqual(store.activeDeviceID, RemoteDevice.remote2Pro.id)

        let target = try XCTUnwrap(RemoteButtonSlot.demoSlots.first(where: { $0.id == "tv" }))
        store.selectSlot(target)

        XCTAssertEqual(store.action(for: target.id)?.id, "smart-meeting")

        let restored = AppStore(configurationStore: LocalConfigurationStore(fileURL: configurationURL))
        XCTAssertEqual(restored.action(for: target.id)?.id, "smart-meeting")
    }

    @MainActor
    func testCreatedSmartActionPersistsAndReloads() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCodingSmartActions-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let configurationStore = LocalConfigurationStore(
            fileURL: directory.appendingPathComponent("config.json")
        )
        let initialStore = AppStore(configurationStore: configurationStore)
        let template = try XCTUnwrap(SmartAction.samples.first)
        XCTAssertTrue(initialStore.smartActions.isEmpty)
        XCTAssertTrue(initialStore.installedSmartActionCatalog.isEmpty)
        let created = SmartAction(
            id: "custom-focus",
            actionID: template.actionID,
            title: "开始工作",
            subtitle: template.subtitle,
            symbol: template.symbol,
            tint: template.tint,
            stepCount: template.stepCount
        )

        initialStore.addSmartAction(created)
        XCTAssertEqual(initialStore.installedSmartActionCatalog.map(\.id), [template.actionID])

        let reloadedStore = AppStore(configurationStore: configurationStore)
        XCTAssertEqual(
            reloadedStore.smartActions.first(where: { $0.id == created.id })?.title,
            "开始工作"
        )
        XCTAssertEqual(
            reloadedStore.smartActions.first(where: { $0.id == created.id })?.actionID,
            template.actionID
        )

        let renamed = SmartAction(
            id: created.id,
            actionID: created.actionID,
            title: "开始深度工作",
            subtitle: created.subtitle,
            symbol: created.symbol,
            tint: created.tint,
            stepCount: created.stepCount
        )
        reloadedStore.updateSmartAction(renamed)

        let renamedStore = AppStore(configurationStore: configurationStore)
        XCTAssertEqual(
            renamedStore.smartActions.first(where: { $0.id == created.id })?.title,
            "开始深度工作"
        )

        renamedStore.removeSmartAction(id: created.id)
        let removedStore = AppStore(configurationStore: configurationStore)
        XCTAssertNil(removedStore.smartActions.first(where: { $0.id == created.id }))

        removedStore.removeSmartAction(id: template.id)
        XCTAssertTrue(removedStore.smartActions.isEmpty)
    }

    @MainActor
    func testCustomWorkflowPersistsExecutesAssignsAndCleansUp() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCodingCustomWorkflow-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let configurationURL = directory.appendingPathComponent("config.json")
        let store = AppStore(
            configurationStore: LocalConfigurationStore(fileURL: configurationURL)
        )
        let custom = SmartAction(
            id: "custom-workflow",
            actionID: "custom-smart-test",
            title: "写作准备",
            subtitle: "2 个步骤 · 打开备忘录、音量增加",
            symbol: "note.text",
            tint: .yellow,
            stepCount: 2,
            stepActionIDs: ["launch-notes", "volume-up"]
        )

        store.addSmartAction(custom)
        XCTAssertEqual(store.installedSmartActionCatalog.map(\.id), ["custom-smart-test"])
        XCTAssertEqual(store.installedSmartActionCatalog.first?.title, "写作准备")
        XCTAssertEqual(
            store.command(for: custom.actionID),
            .sequence([
                .sequence([
                    .openApplication(bundleIdentifier: "com.apple.Notes"),
                    .delay(milliseconds: 450),
                    .keyStroke(keyCode: 45, flags: UInt64(1 << 20))
                ]),
                .system(.volumeUp)
            ])
        )

        store.beginAssigningSmartAction(custom)
        let slot = try XCTUnwrap(RemoteButtonSlot.demoSlots.first(where: { $0.id == "tv" }))
        store.selectSlot(slot)
        XCTAssertEqual(store.action(for: slot.id)?.title, "写作准备")

        let reloaded = AppStore(
            configurationStore: LocalConfigurationStore(fileURL: configurationURL)
        )
        XCTAssertEqual(reloaded.smartActions.first?.stepActionIDs, ["launch-notes", "volume-up"])
        XCTAssertEqual(reloaded.action(for: slot.id)?.id, "custom-smart-test")
        XCTAssertNotNil(reloaded.command(for: "custom-smart-test"))

        reloaded.removeSmartAction(id: custom.id)
        XCTAssertNil(reloaded.action(for: slot.id))

        let removed = AppStore(
            configurationStore: LocalConfigurationStore(fileURL: configurationURL)
        )
        XCTAssertNil(removed.action(for: slot.id))
        XCTAssertTrue(removed.smartActions.isEmpty)
    }

    @MainActor
    func testParameterizedWorkflowStepsPersistAndResolveInOrder() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCodingParameterizedWorkflow-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let configurationURL = directory.appendingPathComponent("config.json")
        let steps: [SmartActionStep] = [
            .application(bundleIdentifier: "com.apple.Notes", name: "备忘录"),
            .delay(milliseconds: 1_200),
            .text("每周项目进度"),
            .keystroke(keyCode: 36, flags: 0, name: "Return"),
            .url("https://example.com/status")
        ]
        let action = SmartAction(
            id: "parameterized-workflow",
            actionID: "custom-smart-parameterized",
            title: "写周报",
            subtitle: SmartAction.workflowSubtitle(for: steps),
            symbol: steps[0].symbol,
            tint: steps[0].tint,
            stepCount: SmartAction.workflowStepCount(for: steps),
            steps: steps,
            triggers: [
                .device,
                .application(bundleIdentifier: "com.apple.Safari", name: "Safari"),
                .shortcut(
                    keyCode: 15,
                    flags: UInt64((1 << 17) | (1 << 20)),
                    name: "⇧⌘R"
                )
            ]
        )
        let store = AppStore(
            configurationStore: LocalConfigurationStore(fileURL: configurationURL)
        )

        store.addSmartAction(action)

        let reloaded = AppStore(
            configurationStore: LocalConfigurationStore(fileURL: configurationURL)
        )
        XCTAssertEqual(reloaded.smartActions.first?.steps, steps)
        XCTAssertEqual(reloaded.smartActions.first?.triggers, action.triggers)
        XCTAssertNil(reloaded.smartActions.first?.stepActionIDs)
        XCTAssertEqual(
            reloaded.command(for: action.actionID),
            .sequence([
                .openApplication(bundleIdentifier: "com.apple.Notes"),
                .delay(milliseconds: 1_200),
                .typeText("每周项目进度"),
                .keyStroke(keyCode: 36, flags: 0),
                .openURL("https://example.com/status")
            ])
        )

        let exported = try JSONEncoder().encode([action.persistedRepresentation])
        let imported = try JSONDecoder().decode([PersistedSmartAction].self, from: exported)
        XCTAssertEqual(imported.first?.steps, steps)
        XCTAssertEqual(imported.first?.triggers, action.triggers)
    }

    @MainActor
    func testApplicationOperationsAndEnabledStatePersist() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCodingApplicationOperations-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let configurationURL = directory.appendingPathComponent("config.json")
        let steps: [SmartActionStep] = [
            .applicationControl(
                bundleIdentifier: "com.apple.Notes",
                name: "备忘录",
                operation: .bringToFront
            ),
            .applicationControl(
                bundleIdentifier: "com.apple.Music",
                name: "音乐",
                operation: .close
            )
        ]
        let action = SmartAction(
            id: "application-operations",
            actionID: "custom-smart-application-operations",
            title: "整理工作区",
            subtitle: SmartAction.workflowSubtitle(for: steps),
            symbol: "app.dashed",
            tint: .blue,
            stepCount: 2,
            steps: steps,
            triggers: [.device],
            isEnabled: false
        )
        let store = AppStore(
            configurationStore: LocalConfigurationStore(fileURL: configurationURL)
        )

        store.addSmartAction(action)

        var reloaded = AppStore(
            configurationStore: LocalConfigurationStore(fileURL: configurationURL)
        )
        XCTAssertFalse(try XCTUnwrap(reloaded.smartActions.first).isEnabled)
        XCTAssertEqual(
            reloaded.command(for: action.actionID),
            .sequence([
                .controlApplication(
                    bundleIdentifier: "com.apple.Notes",
                    operation: .bringToFront
                ),
                .controlApplication(
                    bundleIdentifier: "com.apple.Music",
                    operation: .close
                )
            ])
        )

        reloaded.setSmartActionEnabled(id: action.id, enabled: true)
        reloaded = AppStore(
            configurationStore: LocalConfigurationStore(fileURL: configurationURL)
        )
        XCTAssertTrue(try XCTUnwrap(reloaded.smartActions.first).isEnabled)
    }

    @MainActor
    func testGlobalShortcutMatcherUsesExactKeyAndModifiers() {
        let bindings = [
            GlobalShortcutBinding(
                actionID: "custom-smart-report",
                keyCode: 15,
                flags: UInt64((1 << 17) | (1 << 20))
            )
        ]

        XCTAssertEqual(
            GlobalShortcutMonitor.actionID(
                forKeyCode: 15,
                flags: UInt64((1 << 17) | (1 << 20)),
                in: bindings
            ),
            "custom-smart-report"
        )
        XCTAssertNil(
            GlobalShortcutMonitor.actionID(
                forKeyCode: 15,
                flags: UInt64(1 << 20),
                in: bindings
            )
        )
        XCTAssertFalse(
            SmartActionTrigger.shortcut(keyCode: 15, flags: 0, name: "R").isValid
        )
    }

    @MainActor
    func testConflictingGlobalShortcutCannotBeEnabled() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-ShortcutConflict-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppStore(configurationStore: LocalConfigurationStore(
            fileURL: directory.appendingPathComponent("config.json")
        ))
        let shortcut = SmartActionTrigger.shortcut(
            keyCode: 15,
            flags: UInt64((1 << 17) | (1 << 20)),
            name: "⇧⌘R"
        )
        let first = SmartAction(
            id: "shortcut-conflict-first",
            actionID: "custom-smart-shortcut-first",
            title: "第一个工作流",
            subtitle: "1 个步骤",
            symbol: "calendar",
            tint: .purple,
            stepCount: 1,
            steps: [.action("launch-calendar")],
            triggers: [shortcut]
        )
        let second = SmartAction(
            id: "shortcut-conflict-second",
            actionID: "custom-smart-shortcut-second",
            title: "第二个工作流",
            subtitle: "1 个步骤",
            symbol: "note.text",
            tint: .yellow,
            stepCount: 1,
            steps: [.action("launch-notes")],
            triggers: [shortcut],
            isEnabled: false
        )

        store.addSmartAction(first)
        store.addSmartAction(second)

        XCTAssertFalse(store.setSmartActionEnabled(id: second.id, enabled: true))
        XCTAssertFalse(try XCTUnwrap(store.smartActions.first(where: { $0.id == second.id })).isEnabled)
        XCTAssertEqual(
            store.toastMessage,
            "无法启用：全局快捷键已用于“第一个工作流”"
        )

        let restored = AppStore(configurationStore: LocalConfigurationStore(
            fileURL: directory.appendingPathComponent("config.json")
        ))
        XCTAssertFalse(try XCTUnwrap(restored.smartActions.first(where: { $0.id == second.id })).isEnabled)
    }

    @MainActor
    func testAddedAndUpdatedSmartActionsCannotBypassShortcutConflictProtection() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-ShortcutMutationConflict-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppStore(
            configurationStore: LocalConfigurationStore(
                fileURL: directory.appendingPathComponent("config.json")
            ),
            runtimeServicesEnabled: false
        )
        let shortcut = SmartActionTrigger.shortcut(
            keyCode: 15,
            flags: UInt64((1 << 17) | (1 << 20)),
            name: "⇧⌘R"
        )
        let first = SmartAction(
            id: "shortcut-mutation-first",
            actionID: "custom-smart-mutation-first",
            title: "保留启用",
            subtitle: "1 个步骤",
            symbol: "calendar",
            tint: .purple,
            stepCount: 1,
            steps: [.action("launch-calendar")],
            triggers: [shortcut]
        )
        let second = SmartAction(
            id: "shortcut-mutation-second",
            actionID: "custom-smart-mutation-second",
            title: "导入冲突项",
            subtitle: "1 个步骤",
            symbol: "note.text",
            tint: .yellow,
            stepCount: 1,
            steps: [.action("launch-notes")],
            triggers: [shortcut]
        )

        XCTAssertTrue(store.addSmartAction(first).isEnabled)
        XCTAssertFalse(store.addSmartAction(second).isEnabled)
        XCTAssertEqual(
            store.toastMessage,
            "已创建“导入冲突项”，但因快捷键与“保留启用”冲突已停用"
        )

        let updated = store.updateSmartAction(second.withEnabled(true))
        XCTAssertFalse(updated.isEnabled)
        XCTAssertFalse(try XCTUnwrap(store.smartActions.first(where: { $0.id == second.id })).isEnabled)
        XCTAssertEqual(
            store.toastMessage,
            "已更新“导入冲突项”，但因快捷键与“保留启用”冲突已停用"
        )
    }

    @MainActor
    func testLegacyEnabledShortcutConflictsAreNormalizedAndPersistedOnLaunch() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-LegacyShortcutConflict-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configurationStore = LocalConfigurationStore(
            fileURL: directory.appendingPathComponent("config.json")
        )
        let shortcut = SmartActionTrigger.shortcut(
            keyCode: 15,
            flags: UInt64((1 << 17) | (1 << 20)),
            name: "⇧⌘R"
        )
        let makeAction: (String, String) -> SmartAction = { id, title in
            SmartAction(
                id: id,
                actionID: "custom-smart-\(id)",
                title: title,
                subtitle: "1 个步骤",
                symbol: "bolt",
                tint: .purple,
                stepCount: 1,
                steps: [.action("launch-calendar")],
                triggers: [shortcut]
            )
        }
        let first = makeAction("legacy-shortcut-first", "旧工作流一")
        let second = makeAction("legacy-shortcut-second", "旧工作流二")
        try configurationStore.save(
            PersistedConfiguration(
                assignmentsByProfile: ["global": [:]],
                customSmartActions: [
                    first.persistedRepresentation,
                    second.persistedRepresentation
                ]
            )
        )

        let restored = AppStore(
            configurationStore: configurationStore,
            runtimeServicesEnabled: false
        )
        XCTAssertEqual(restored.smartActions.map(\.isEnabled), [true, false])

        let persisted = try XCTUnwrap(configurationStore.load())
        XCTAssertEqual(
            try XCTUnwrap(persisted.customSmartActions).map { $0.isEnabled ?? true },
            [true, false]
        )

        let reloaded = AppStore(
            configurationStore: configurationStore,
            runtimeServicesEnabled: false
        )
        XCTAssertEqual(reloaded.smartActions.map(\.isEnabled), [true, false])
    }

    @MainActor
    func testApplicationTriggerMatchesActivatedBundleIdentifier() {
        let bindings = [
            ApplicationTriggerBinding(
                actionID: "custom-smart-browser-ready",
                bundleIdentifier: "com.apple.Safari"
            ),
            ApplicationTriggerBinding(
                actionID: "custom-smart-notes-ready",
                bundleIdentifier: "com.apple.Notes"
            ),
            ApplicationTriggerBinding(
                actionID: "custom-smart-browser-second",
                bundleIdentifier: "com.apple.Safari"
            )
        ]

        XCTAssertEqual(
            BackendCoordinator.applicationActionIDs(
                for: "com.apple.Safari",
                in: bindings
            ),
            ["custom-smart-browser-ready", "custom-smart-browser-second"]
        )
        XCTAssertEqual(
            BackendCoordinator.applicationActionIDs(for: nil, in: bindings),
            []
        )
        XCTAssertTrue(
            SmartActionTrigger.application(
                bundleIdentifier: "com.apple.Safari",
                name: "Safari"
            ).isValid
        )
        XCTAssertFalse(
            SmartActionTrigger.application(bundleIdentifier: "", name: "Safari").isValid
        )
    }

    func testLegacyPersistedSmartActionWithoutStepsStillDecodes() throws {
        let data = try XCTUnwrap(
            #"{"id":"legacy","actionID":"smart-focus","title":"旧版办公模式"}"#
                .data(using: .utf8)
        )
        let persisted = try JSONDecoder().decode(PersistedSmartAction.self, from: data)

        XCTAssertNil(persisted.stepActionIDs)
        XCTAssertNil(persisted.isEnabled)
        let restored = try XCTUnwrap(SmartAction.restored(from: persisted))
        XCTAssertEqual(restored.actionID, "smart-focus")
        XCTAssertEqual(restored.stepCount, 3)
        XCTAssertNil(restored.stepActionIDs)
        XCTAssertTrue(restored.isEnabled)
    }

    @MainActor
    func testBackendCoordinatorUsesCustomCommandResolver() {
        let executor = RecordingActionExecutor()
        let coordinator = BackendCoordinator(executor: executor, keyRemapper: nil)
        coordinator.resolveCommand = { actionID in
            actionID == "custom-smart-test"
                ? .sequence([.openDefaultBrowser, .system(.mute)])
                : nil
        }

        coordinator.execute(actionID: "custom-smart-test", source: "test")

        XCTAssertEqual(
            executor.commands,
            [.sequence([.openDefaultBrowser, .system(.mute)])]
        )
    }

    @MainActor
    func testHoldAndDoubleTapAssignmentsPersistIndependently() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("XiaomiRemoteStudioTriggers-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let configurationStore = LocalConfigurationStore(
            fileURL: directory.appendingPathComponent("config.json")
        )
        let store = AppStore(configurationStore: configurationStore)
        let slot = try XCTUnwrap(RemoteButtonSlot.demoSlots.first(where: { $0.id == "ok" }))
        let holdAction = try XCTUnwrap(RemoteAction.catalog.first(where: { $0.id == "copy" }))
        let doubleAction = try XCTUnwrap(RemoteAction.catalog.first(where: { $0.id == "paste" }))

        store.openDevice(.remote2Pro)
        store.selectedTrigger = .hold
        store.assign(holdAction, to: slot)
        store.selectedTrigger = .doubleTap
        store.assign(doubleAction, to: slot)

        let reloaded = AppStore(configurationStore: configurationStore)
        XCTAssertEqual(reloaded.action(for: slot.id, trigger: .hold)?.id, "copy")
        XCTAssertEqual(reloaded.action(for: slot.id, trigger: .doubleTap)?.id, "paste")
        XCTAssertEqual(reloaded.action(for: slot.id, trigger: .tap)?.id, "play-pause")
    }

    @MainActor
    func testGestureTimingSettingsClampPersistAndReload() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("XiaomiRemoteStudioTiming-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let configurationStore = LocalConfigurationStore(
            fileURL: directory.appendingPathComponent("config.json")
        )
        let store = AppStore(configurationStore: configurationStore)

        store.setHoldMilliseconds(900)
        store.setDoubleTapMilliseconds(100)
        store.setDebounceMilliseconds(400)

        XCTAssertEqual(store.holdMilliseconds, 800)
        XCTAssertEqual(store.doubleTapMilliseconds, 150)
        XCTAssertEqual(store.debounceMilliseconds, 100)

        let reloaded = AppStore(configurationStore: configurationStore)
        XCTAssertEqual(reloaded.holdMilliseconds, 800)
        XCTAssertEqual(reloaded.doubleTapMilliseconds, 150)
        XCTAssertEqual(reloaded.debounceMilliseconds, 100)
    }

    @MainActor
    func testClearingAssignmentOnlyAffectsSelectedTrigger() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("XiaomiRemoteStudioClear-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = AppStore(configurationStore: LocalConfigurationStore(
            fileURL: directory.appendingPathComponent("config.json")
        ))
        let slot = try XCTUnwrap(RemoteButtonSlot.demoSlots.first(where: { $0.id == "ok" }))
        let action = try XCTUnwrap(RemoteAction.catalog.first(where: { $0.id == "copy" }))

        store.openDevice(.remote2Pro)
        store.selectedTrigger = .hold
        store.assign(action, to: slot)
        store.clearSelectedAssignment()

        XCTAssertNil(store.action(for: slot.id, trigger: .hold))
        XCTAssertEqual(store.action(for: slot.id, trigger: .tap)?.id, "play-pause")
    }

    func testActionCatalogResolvesToExecutableCommands() {
        XCTAssertEqual(ActionCommand.command(for: "spotlight"), .system(.spotlight))
        XCTAssertEqual(ActionCommand.command(for: "volume-up"), .system(.volumeUp))
        XCTAssertEqual(
            ActionCommand.command(for: "keyboard-shortcut"),
            .keyStroke(keyCode: 40, flags: UInt64(1 << 20))
        )
        XCTAssertEqual(ActionCommand.command(for: "launch-browser"), .openDefaultBrowser)
        XCTAssertEqual(
            ActionCommand.command(for: "launch-notes"),
            .sequence([
                .openApplication(bundleIdentifier: "com.apple.Notes"),
                .delay(milliseconds: 450),
                .keyStroke(keyCode: 45, flags: UInt64(1 << 20))
            ])
        )
        XCTAssertEqual(
            ActionCommand.command(for: "emoji-picker"),
            .keyStroke(keyCode: 49, flags: UInt64((1 << 20) | (1 << 18)))
        )
        XCTAssertEqual(
            ActionCommand.command(for: "explore-ai"),
            .openURL("https://chatgpt.com")
        )
        XCTAssertEqual(
            ActionCommand.command(for: "launch-micoding"),
            .openApplication(bundleIdentifier: "io.xiaomiremote.studio")
        )
        XCTAssertEqual(
            ActionCommand.command(for: "smart-netflix"),
            .sequence([.openURL("https://www.netflix.com")])
        )
        XCTAssertEqual(
            ActionCommand.command(for: "smart-google-work"),
            .sequence([
                .openURL("https://mail.google.com"),
                .openURL("https://drive.google.com"),
                .openURL("https://calendar.google.com")
            ])
        )
        XCTAssertEqual(
            ActionCommand.command(for: "smart-ai-work"),
            .sequence([.openURL("https://chatgpt.com")])
        )
        XCTAssertEqual(
            ActionCommand.command(for: "smart-web-search"),
            .sequence([.searchSelectedText])
        )
        XCTAssertEqual(
            ActionCommand.command(for: "smart-ai-reply"),
            .sequence([.openURLWithSelectedTextPrompt(
                url: "https://chatgpt.com",
                instruction: "请根据以下消息起草一份简洁、自然的回复："
            )])
        )
        XCTAssertEqual(
            ActionCommand.command(for: "smart-ai-summary"),
            .sequence([.openURLWithSelectedTextPrompt(
                url: "https://chatgpt.com",
                instruction: "请用要点总结以下文本："
            )])
        )
        XCTAssertEqual(ActionCommand.command(for: "show-actions-ring"), .showActionsRing)
        XCTAssertEqual(ActionCommand.command(for: "unknown"), .none)

        for action in RemoteAction.catalog {
            XCTAssertNotEqual(
                ActionCommand.command(for: action.id),
                .none,
                "\(action.id) 必须具备可执行命令"
            )
        }
    }

    func testActionsRingFolderProvidesNineExecutableSubActions() throws {
        let folder = try XCTUnwrap(
            ActionsRingFolderCatalog.definition(for: "actions-ring-folder-work")
        )
        XCTAssertEqual(folder.title, "工作模式")
        XCTAssertEqual(folder.actionIDs.count, 9)
        XCTAssertEqual(Set(folder.actionIDs).count, 9)
        XCTAssertEqual(folder.actions.count, 9)
        XCTAssertTrue(folder.actions.allSatisfy {
            ActionsRingFolderCatalog.definition(for: $0.id) == nil
                && ActionCommand.command(for: $0.id) != .none
        })
    }

    @MainActor
    func testActionsRingParameterActionsMapToNativeControlsAndScrollEvents() throws {
        let volume = try XCTUnwrap(
            RemoteAction.catalog.first(where: { $0.id == "volume-adjust" })
        )
        let brightness = try XCTUnwrap(
            RemoteAction.catalog.first(where: { $0.id == "brightness-adjust" })
        )
        XCTAssertEqual(volume.actionsRingParameterKind, .volume)
        XCTAssertEqual(brightness.actionsRingParameterKind, .brightness)
        XCTAssertEqual(ActionCommand.command(for: volume.id), .system(.volumeUp))
        XCTAssertEqual(ActionCommand.command(for: brightness.id), .system(.brightnessUp))
        XCTAssertEqual(ActionCommand.command(for: "brightness-down"), .system(.brightnessDown))

        let interaction = ActionsRingOverlayInteractionModel()
        interaction.postScroll(deltaY: 2.5)
        XCTAssertEqual(interaction.scrollSequence, 1)
        XCTAssertEqual(interaction.scrollDelta, 1)
        interaction.postScroll(deltaY: -0.5)
        XCTAssertEqual(interaction.scrollSequence, 2)
        XCTAssertEqual(interaction.scrollDelta, -1)

        let store = AppStore(runtimeServicesEnabled: false)
        store.adjustActionsRingParameter(volume, by: 2)
        XCTAssertEqual(store.backendLog, "Actions Ring 已调节音量")
        store.adjustActionsRingParameter(brightness, by: -1)
        XCTAssertEqual(store.backendLog, "Actions Ring 已调节亮度")
    }

    func testSelectedTextPromptBuilderTrimsClipsAndBuildsDestination() throws {
        let prompt = try XCTUnwrap(SelectedTextPromptBuilder.prompt(
            instruction: "  请总结：  ",
            selection: "  abcdef  ",
            maxSelectionCharacters: 4
        ))
        XCTAssertEqual(prompt, "请总结：\n\nabcd")
        XCTAssertNil(SelectedTextPromptBuilder.prompt(
            instruction: "请总结：",
            selection: "  "
        ))

        let destination = try XCTUnwrap(SelectedTextPromptBuilder.destinationURL(
            baseURL: "https://chatgpt.com/?model=auto&q=old",
            prompt: prompt
        ))
        let components = try XCTUnwrap(URLComponents(
            url: destination,
            resolvingAgainstBaseURL: false
        ))
        XCTAssertEqual(
            components.queryItems?.first(where: { $0.name == "model" })?.value,
            "auto"
        )
        XCTAssertEqual(components.queryItems?.filter { $0.name == "q" }.count, 1)
        XCTAssertEqual(
            components.queryItems?.first(where: { $0.name == "q" })?.value,
            prompt
        )
    }

    func testAITextTemplatesHaveDistinctTaskInstructions() throws {
        let actionIDs = [
            "smart-ai-reply",
            "smart-ai-grammar",
            "smart-ai-summary",
            "smart-ai-translate",
            "smart-ai-code"
        ]
        let commands = actionIDs.map(ActionCommand.command(for:))

        XCTAssertEqual(Set(commands.map(String.init(describing:))).count, actionIDs.count)
        for command in commands {
            guard case let .sequence(steps) = command,
                  steps.count == 1,
                  let step = steps.first,
                  case let .openURLWithSelectedTextPrompt(url, instruction) = step else {
                return XCTFail("AI 文本模板必须生成所选文本提示词")
            }
            XCTAssertEqual(url, "https://chatgpt.com")
            XCTAssertFalse(instruction.isEmpty)
        }
    }

    func testSmartActionStepValidationRejectsIncompleteConfiguration() {
        XCTAssertFalse(SmartActionStep.url("").isValid)
        XCTAssertFalse(SmartActionStep.url("https://").isValid)
        XCTAssertFalse(SmartActionStep.url("mailto:test@example.com").isValid)
        XCTAssertEqual(
            SmartActionStep.url("  https://example.com/path  ").command,
            .openURL("https://example.com/path")
        )

        XCTAssertFalse(SmartActionStep.text("").isValid)
        XCTAssertFalse(SmartActionStep.text(String(repeating: "a", count: 1_001)).isValid)
        XCTAssertTrue(SmartActionStep.text(String(repeating: "a", count: 1_000)).isValid)

        XCTAssertFalse(
            SmartActionStep.application(bundleIdentifier: "", name: "访达").isValid
        )
        XCTAssertFalse(
            SmartActionStep.application(bundleIdentifier: "com.apple.finder", name: "").isValid
        )
        XCTAssertFalse(
            SmartActionStep.applicationPath(path: "Applications/Test.app", name: "Test").isValid
        )
        XCTAssertFalse(
            SmartActionStep.applicationPath(path: "/Applications/Test.txt", name: "Test").isValid
        )
        XCTAssertTrue(
            SmartActionStep.applicationPath(path: "/Applications/Test.app", name: "Test").isValid
        )
        XCTAssertFalse(SmartActionStep.delay(milliseconds: 99).isValid)
        XCTAssertTrue(SmartActionStep.delay(milliseconds: 100).isValid)
        XCTAssertFalse(SmartActionStep.delay(milliseconds: 100_000).isValid)
    }

    @MainActor
    func testRecordedKeyboardShortcutAssignsExecutesAndPersists() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-RecordedShortcutTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configurationStore = LocalConfigurationStore(
            fileURL: directory.appendingPathComponent("config.json")
        )
        let store = AppStore(configurationStore: configurationStore)
        store.openDevice(.remote2Pro)
        store.selectedSlotID = "back"

        let action = try XCTUnwrap(store.assignRecordedKeyboardShortcut(
            keyCode: 1,
            flags: UInt64((1 << 20) | (1 << 17)),
            displayName: "⌘⇧S"
        ))

        XCTAssertTrue(action.id.hasPrefix("recorded-keyboard-shortcut-"))
        XCTAssertEqual(store.action(for: "back")?.title, "高级键盘映射")
        XCTAssertEqual(
            store.command(for: action.id),
            .sequence([.keyStroke(keyCode: 1, flags: UInt64((1 << 20) | (1 << 17)))])
        )

        let reloaded = AppStore(configurationStore: configurationStore)
        reloaded.openDevice(.remote2Pro)
        XCTAssertEqual(reloaded.action(for: "back")?.title, "高级键盘映射")
        XCTAssertEqual(
            reloaded.command(for: action.id),
            .sequence([.keyStroke(keyCode: 1, flags: UInt64((1 << 20) | (1 << 17)))])
        )
    }

    @MainActor
    func testSelectedApplicationAssignsExecutesReusesAndPersists() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-SelectedApplicationTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let applicationURL = directory.appendingPathComponent("Demo Tool.app", isDirectory: true)
        try FileManager.default.createDirectory(at: applicationURL, withIntermediateDirectories: true)
        let configurationStore = LocalConfigurationStore(
            fileURL: directory.appendingPathComponent("config.json")
        )
        let store = AppStore(configurationStore: configurationStore)
        store.openDevice(.remote2Pro)
        store.selectedSlotID = "tv"

        let action = try XCTUnwrap(store.assignApplication(
            at: applicationURL,
            displayName: "Demo Tool"
        ))

        XCTAssertEqual(store.action(for: "tv")?.title, "打开 Demo Tool")
        XCTAssertEqual(
            store.command(for: action.id),
            .sequence([.openApplicationAtPath(applicationURL.standardizedFileURL.path)])
        )
        XCTAssertEqual(store.smartActions.count, 1)

        store.selectedSlotID = "power"
        store.selectedTrigger = .hold
        let reused = try XCTUnwrap(store.assignApplication(
            at: applicationURL,
            displayName: "Demo Tool"
        ))
        XCTAssertEqual(reused.id, action.id)
        XCTAssertEqual(store.smartActions.count, 1)
        XCTAssertEqual(store.action(for: "power", trigger: .hold)?.id, action.id)

        let reloaded = AppStore(configurationStore: configurationStore)
        XCTAssertEqual(reloaded.action(for: "tv")?.title, "打开 Demo Tool")
        XCTAssertEqual(reloaded.action(for: "power", trigger: .hold)?.title, "打开 Demo Tool")
        XCTAssertEqual(
            reloaded.command(for: action.id),
            .sequence([.openApplicationAtPath(applicationURL.standardizedFileURL.path)])
        )
    }

    @MainActor
    func testAdvancedShortcutNamesCoverModifiersFunctionAndNavigationKeys() throws {
        XCTAssertEqual(
            ShortcutRecorderNSView.displayName(
                keyCode: 1,
                characters: "s",
                modifiers: [.command, .shift]
            ),
            "⇧⌘S"
        )
        XCTAssertEqual(
            ShortcutRecorderNSView.displayName(
                keyCode: 122,
                characters: nil,
                modifiers: []
            ),
            "F1"
        )
        XCTAssertEqual(
            ShortcutRecorderNSView.displayName(
                keyCode: 121,
                characters: nil,
                modifiers: [.option]
            ),
            "⌥Page Down"
        )
        XCTAssertEqual(
            ShortcutRecorderNSView.displayName(
                keyCode: 63,
                characters: nil,
                modifiers: [.function]
            ),
            "fn"
        )
        XCTAssertEqual(
            ShortcutRecorderNSView.displayName(
                keyCode: 122,
                characters: nil,
                modifiers: [.function]
            ),
            "fn F1"
        )

        let recorder = ShortcutRecorderNSView(frame: NSRect(x: 0, y: 0, width: 180, height: 40))
        var recorded: [(UInt16, UInt64, String)] = []
        recorder.onRecord = { recorded.append(($0, $1, $2)) }

        let fnDown = try XCTUnwrap(NSEvent.keyEvent(
            with: .flagsChanged,
            location: .zero,
            modifierFlags: [.function],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: 63
        ))
        let fnUp = try XCTUnwrap(NSEvent.keyEvent(
            with: .flagsChanged,
            location: .zero,
            modifierFlags: [],
            timestamp: 0.1,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: 63
        ))
        recorder.flagsChanged(with: fnDown)
        XCTAssertTrue(recorded.isEmpty)
        recorder.flagsChanged(with: fnUp)
        XCTAssertEqual(recorded.count, 1)
        XCTAssertEqual(recorded[0].0, 63)
        XCTAssertEqual(recorded[0].1, UInt64(NSEvent.ModifierFlags.function.rawValue))
        XCTAssertEqual(recorded[0].2, "fn")

        // The live modifier-state fallback must finish recording even if
        // AppKit never delivers the fn-up event (for example when Globe opens
        // the input-source or emoji UI).
        recorded.removeAll()
        recorder.flagsChanged(with: fnDown)
        recorder.observeFunctionModifierState(currentModifiers: [])
        XCTAssertEqual(recorded.count, 1)
        XCTAssertEqual(recorded[0].0, 63)
        XCTAssertEqual(recorded[0].1, UInt64(NSEvent.ModifierFlags.function.rawValue))
        XCTAssertEqual(recorded[0].2, "fn")

        // A reserved system Globe shortcut can also swallow fn-down. The
        // focused recorder's state poller must detect the full transition
        // without receiving either AppKit event.
        recorded.removeAll()
        recorder.observeFunctionModifierState(currentModifiers: [.function])
        recorder.observeFunctionModifierState(currentModifiers: [])
        XCTAssertEqual(recorded.count, 1)
        XCTAssertEqual(recorded[0].0, 63)
        XCTAssertEqual(recorded[0].1, UInt64(NSEvent.ModifierFlags.function.rawValue))
        XCTAssertEqual(recorded[0].2, "fn")

        // Persistent state such as Caps Lock must not make fn look as if it
        // were still held after the physical key has been released.
        recorded.removeAll()
        let fnDownWithCapsLock = try XCTUnwrap(NSEvent.keyEvent(
            with: .flagsChanged,
            location: .zero,
            modifierFlags: [.function, .capsLock],
            timestamp: 0.11,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: 63
        ))
        let fnUpWithCapsLock = try XCTUnwrap(NSEvent.keyEvent(
            with: .flagsChanged,
            location: .zero,
            modifierFlags: [.capsLock],
            timestamp: 0.12,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: 63
        ))
        recorder.flagsChanged(with: fnDownWithCapsLock)
        recorder.flagsChanged(with: fnUpWithCapsLock)
        XCTAssertEqual(recorded.count, 1)
        XCTAssertEqual(recorded[0].2, "fn")

        recorded.removeAll()
        let commandDown = try XCTUnwrap(NSEvent.keyEvent(
            with: .flagsChanged,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0.2,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: 55
        ))
        let commandC = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0.3,
            windowNumber: 0,
            context: nil,
            characters: "c",
            charactersIgnoringModifiers: "c",
            isARepeat: false,
            keyCode: 8
        ))
        recorder.flagsChanged(with: commandDown)
        recorder.keyDown(with: commandC)
        recorder.flagsChanged(with: fnUp)
        XCTAssertEqual(recorded.count, 1)
        XCTAssertEqual(recorded[0].2, "⌘C")

        let monitoredRecorder = ShortcutRecorderNSView(
            frame: NSRect(x: 0, y: 0, width: 180, height: 40)
        )
        let window = NSWindow(
            contentRect: monitoredRecorder.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.contentView = monitoredRecorder
        XCTAssertTrue(window.makeFirstResponder(monitoredRecorder))

        var monitorRecords: [(UInt16, UInt64, String)] = []
        monitoredRecorder.onRecord = { monitorRecords.append(($0, $1, $2)) }
        XCTAssertNil(monitoredRecorder.handleLocallyMonitoredModifierEvent(fnDown))
        XCTAssertTrue(monitorRecords.isEmpty)
        XCTAssertNil(monitoredRecorder.handleLocallyMonitoredModifierEvent(fnUp))
        XCTAssertEqual(monitorRecords.count, 1)
        XCTAssertEqual(monitorRecords[0].2, "fn")
        XCTAssertFalse(window.firstResponder === monitoredRecorder)

        // Losing focus to a macOS Globe action must not discard fn before the
        // live modifier-state fallback observes its release.
        XCTAssertTrue(window.makeFirstResponder(monitoredRecorder))
        XCTAssertNil(monitoredRecorder.handleLocallyMonitoredModifierEvent(fnDown))
        XCTAssertTrue(window.makeFirstResponder(nil))
        monitoredRecorder.observeFunctionModifierState(currentModifiers: [])
        XCTAssertEqual(monitorRecords.count, 2)
        XCTAssertEqual(monitorRecords[1].2, "fn")

        let autoFocusedRecorder = ShortcutRecorderNSView(
            frame: NSRect(x: 0, y: 0, width: 180, height: 40)
        )
        autoFocusedRecorder.automaticallyActivates = true
        let autoFocusWindow = NSWindow(
            contentRect: autoFocusedRecorder.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        autoFocusWindow.contentView = autoFocusedRecorder
        XCTAssertTrue(autoFocusWindow.firstResponder === autoFocusedRecorder)
    }

    func testSmartActionsResolveToSequencesAndAppearInTheActionLibrary() {
        XCTAssertEqual(SmartAction.samples.count, 27)
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

    func testSmartActionExportPayloadRoundTripsThroughImportFormat() throws {
        let action = try XCTUnwrap(SmartAction.samples.first)
        let data = try JSONEncoder().encode([action.persistedRepresentation])
        let decoded = try JSONDecoder().decode([PersistedSmartAction].self, from: data)

        XCTAssertEqual(decoded, [action.persistedRepresentation])
        XCTAssertTrue(SmartAction.samples.contains(where: {
            $0.actionID == decoded[0].actionID
        }))
    }

    @MainActor
    func testInstalledSmartActionCanResolveWhileDragging() throws {
        let configurationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-DragSmartAction-\(UUID().uuidString).json")
        let store = AppStore(
            configurationStore: LocalConfigurationStore(fileURL: configurationURL)
        )
        let action = SmartAction(
            id: "drag-custom",
            actionID: "custom-smart-drag",
            title: "拖放测试",
            subtitle: "1 个步骤 · 打开浏览器",
            symbol: "globe",
            tint: .blue,
            stepCount: 1,
            steps: [.action("launch-browser")],
            triggers: [.device]
        )

        store.addSmartAction(action)
        store.beginDragging(action.remoteAction)

        XCTAssertEqual(store.draggedAction?.id, action.actionID)
        XCTAssertEqual(store.draggedAction?.title, action.title)
    }

    func testEveryVisibleTemplateCategoryContainsActions() {
        let categories = ["全部", "热门", "生产力", "会议", "AI", "休闲", "设计师", "开发者"]
        for category in categories {
            XCTAssertTrue(
                SmartAction.samples.contains(where: { AutomationFilter.matches(category, action: $0) }),
                "\(category) 分类不应显示空白页"
            )
        }
    }

    func testAutomationNameSortUsesLocalizedTitles() {
        let sorted = AutomationSort.name.sorted(SmartAction.samples)
        let expected = SmartAction.samples.sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
        XCTAssertEqual(sorted.map(\.id), expected.map(\.id))
        XCTAssertEqual(AutomationSort.recent.sorted(SmartAction.samples).map(\.id), SmartAction.samples.map(\.id))
    }

    func testModelAndInterfaceSymbolsResolveToLucideIcons() {
        var symbols: [String] = []
        symbols.append(contentsOf: AppSection.allCases.map(\.icon))
        symbols.append(contentsOf: DevicePanel.allCases.map(\.symbol))
        symbols.append(contentsOf: RemoteButtonSlot.demoSlots.map(\.symbol))
        symbols.append(contentsOf: RemoteAction.catalog.map(\.symbol))
        symbols.append(contentsOf: AppProfile.profiles.map(\.symbol))
        symbols.append(contentsOf: SmartAction.samples.map(\.symbol))

        let representativeSteps: [SmartActionStep] = [
            .application(bundleIdentifier: "test", name: "Test"),
            .keystroke(keyCode: 36, flags: 0, name: "Return"),
            .text("Text"),
            .url("https://example.com"),
            .delay(milliseconds: 1_000)
        ]
        symbols.append(contentsOf: representativeSteps.map(\.symbol))
        symbols.append(contentsOf: AppIconRegistry.interfaceSymbols)

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
        let coordinator = BackendCoordinator(
            inputService: input,
            executor: executor,
            keyRemapper: nil
        )
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
    func testRelayEventIsAuthoritativeWhenDirectHIDAlsoReportsTheSameKey() async {
        let input = PreviewRemoteInputService()
        let remapper = RecordingDeviceKeyRemapper()
        remapper.activeRemappedSlotIDs = ["ok"]
        let coordinator = BackendCoordinator(
            inputService: input,
            keyRemapper: remapper
        )
        var events: [RemoteInputEvent] = []
        coordinator.onInputEvent = { events.append($0) }

        coordinator.start()
        input.emit(slotID: "ok", phase: .began)
        remapper.onEvent?(
            RemoteInputEvent(
                deviceID: RemoteDevice.remote2Pro.id,
                slotID: "ok",
                phase: .began,
                timestamp: Date()
            )
        )
        await Task.yield()

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.slotID, "ok")
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
    func testLocalProfileModalDismissesForNavigationAndDeviceFlows() {
        let store = AppStore()

        store.showLocalProfile()
        XCTAssertTrue(store.showsLocalProfile)

        store.selectSection(.settings)
        XCTAssertFalse(store.showsLocalProfile)

        store.leaveSettings()
        store.showLocalProfile()
        store.openDevice(.remote2Pro)
        XCTAssertFalse(store.showsLocalProfile)

        store.closeDevice()
        store.showLocalProfile()
        store.beginAddingDevice()
        XCTAssertFalse(store.showsLocalProfile)
    }

    @MainActor
    func testExploreCenterRoutesToRealFeatureSurfaces() {
        let store = AppStore()

        store.showExploreCenter()
        XCTAssertTrue(store.showsExploreCenter)

        store.showFeatureOverview()
        XCTAssertFalse(store.showsExploreCenter)
        XCTAssertTrue(store.showsFeatureOverview)

        store.dismissFeatureOverview()
        XCTAssertTrue(store.showsExploreCenter)
        store.openDevice(.remote2Pro)
        XCTAssertFalse(store.showsExploreCenter)
        XCTAssertEqual(store.activeDeviceID, RemoteDevice.remote2Pro.id)

        store.closeDevice()
        store.showExploreCenter()
        store.selectSection(.automations)
        XCTAssertFalse(store.showsExploreCenter)
        XCTAssertEqual(store.activeSection, .automations)

        store.selectSection(.devices)
        store.showExploreCenter()
        store.showActionsRingFromExploreCenter()
        XCTAssertFalse(store.showsExploreCenter)
        XCTAssertTrue(store.showsActionsRing)

        store.closeActionsRing()
        XCTAssertFalse(store.showsActionsRing)
        XCTAssertTrue(store.showsExploreCenter)
    }

    @MainActor
    func testActionsRingNavigationAssignmentAndPersistence() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-ActionsRingTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configurationStore = LocalConfigurationStore(
            fileURL: directory.appendingPathComponent("config.json")
        )
        let store = AppStore(configurationStore: configurationStore)
        let action = try XCTUnwrap(RemoteAction.catalog.first(where: { $0.id == "copy" }))

        store.showActionsRing()
        XCTAssertTrue(store.showsActionsRing)
        XCTAssertFalse(store.editsActionsRing)

        store.editActionsRing()
        XCTAssertNil(store.selectedActionsRingIndex)
        store.selectActionsRingSlot(3)
        store.assignActionToActionsRing(action)
        store.setActionsRingSize(.large)
        XCTAssertEqual(store.actionsRingActionIDs[3], action.id)

        let ringSmartAction = SmartAction(
            id: "ring-smart-action",
            actionID: "custom-smart-ring-test",
            title: "动作环测试",
            subtitle: "1 个步骤",
            symbol: "calendar",
            tint: .purple,
            stepCount: 1,
            steps: [.action("launch-calendar")],
            triggers: [.actionsRing]
        )
        store.addSmartAction(ringSmartAction)
        XCTAssertEqual(store.actionsRingSmartActionCatalog.map(\.id), [ringSmartAction.actionID])
        XCTAssertTrue(SmartActionTrigger.actionsRing.isValid)

        let safariProfile = try XCTUnwrap(store.profiles.first(where: { $0.id == "safari" }))
        let pasteAction = try XCTUnwrap(RemoteAction.catalog.first(where: { $0.id == "paste" }))
        store.selectActionsRingProfile(safariProfile)
        store.selectActionsRingSlot(3)
        store.assignActionToActionsRing(pasteAction)
        XCTAssertEqual(
            store.actionsRingActionIDs(for: safariProfile.bundleIdentifier)[3],
            pasteAction.id
        )
        XCTAssertEqual(store.actionsRingActionIDs(for: nil)[3], action.id)
        XCTAssertEqual(
            store.actionsRingAction(at: 3, for: safariProfile.bundleIdentifier)?.id,
            pasteAction.id,
            "前台应用的 Actions Ring 必须执行该 Profile 中实际显示的动作"
        )
        XCTAssertEqual(
            store.actionsRingAction(at: 3, for: nil)?.id,
            action.id,
            "没有匹配应用时必须回退到全局 Profile"
        )

        store.leaveActionsRingEditor()
        XCTAssertTrue(store.showsActionsRing)
        XCTAssertFalse(store.editsActionsRing)

        store.editActionsRing()
        store.navigateBackFromActionsRing()
        XCTAssertTrue(store.showsActionsRing)
        XCTAssertFalse(store.editsActionsRing)

        let restored = AppStore(configurationStore: configurationStore)
        XCTAssertEqual(restored.actionsRingActionIDs[3], pasteAction.id)
        XCTAssertEqual(restored.actionsRingActionIDs(for: nil)[3], action.id)
        XCTAssertEqual(restored.actionsRingSize, .large)
        XCTAssertEqual(restored.actionsRingSmartActionCatalog.map(\.id), [ringSmartAction.actionID])
        XCTAssertEqual(restored.selectedActionsRingProfileID, safariProfile.id)
        XCTAssertEqual(
            restored.actionsRingActionIDs(for: safariProfile.bundleIdentifier)[3],
            pasteAction.id
        )

        store.selectSection(.settings)
        XCTAssertFalse(store.showsActionsRing)
    }

    @MainActor
    func testLegacyDefaultActionsRingMigratesToFunctionalReferenceActions() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-ActionsRingMigration-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configurationStore = LocalConfigurationStore(
            fileURL: directory.appendingPathComponent("config.json")
        )
        let legacyActions = [
            "play-pause",
            "launch-notes",
            "spotlight",
            "lock",
            "launch-browser",
            "screenshot",
            "mission-control",
            "launch-finder"
        ]
        try configurationStore.save(
            PersistedConfiguration(
                assignmentsByProfile: ["global": [:]],
                actionsRingActionIDs: legacyActions,
                actionsRingAssignmentsByProfile: ["global": legacyActions]
            )
        )

        let store = AppStore(configurationStore: configurationStore, runtimeServicesEnabled: false)

        XCTAssertEqual(store.actionsRingActionIDs, AppStore.defaultActionsRingActionIDs)
        XCTAssertEqual(
            store.actionsRingActions.compactMap { $0?.id },
            AppStore.defaultActionsRingActionIDs
        )
    }

    @MainActor
    func testActionsRingConfigurationCanRoundTripFromDeviceDrawer() {
        let store = AppStore(runtimeServicesEnabled: false)
        store.openDevice(.remote2Pro)
        store.selectedSlotID = "left"

        store.showActionsRingFromDeviceDetail()

        XCTAssertTrue(store.showsActionsRing)
        XCTAssertEqual(store.activeDeviceID, RemoteDevice.remote2Pro.id)
        XCTAssertNil(store.selectedSlotID)

        store.closeActionsRing()

        XCTAssertFalse(store.showsActionsRing)
        XCTAssertEqual(
            store.activeDeviceID,
            RemoteDevice.remote2Pro.id,
            "从动作说明卡进入配置后，返回必须回到原设备而不是设备首页"
        )
    }

    @MainActor
    func testActionsRingOverlaySizingAndScreenEdgeClamping() {
        XCTAssertEqual(ActionsRingOverlayController.panelSide(for: .small), 440)
        XCTAssertEqual(ActionsRingOverlayController.panelSide(for: .medium), 520)
        XCTAssertEqual(ActionsRingOverlayController.panelSide(for: .large), 620)

        let visibleFrame = CGRect(x: 100, y: 50, width: 800, height: 600)
        XCTAssertEqual(
            ActionsRingOverlayController.panelOrigin(
                cursor: CGPoint(x: 500, y: 350),
                side: 420,
                visibleFrame: visibleFrame
            ),
            CGPoint(x: 290, y: 140)
        )
        XCTAssertEqual(
            ActionsRingOverlayController.panelOrigin(
                cursor: CGPoint(x: 100, y: 50),
                side: 420,
                visibleFrame: visibleFrame
            ),
            CGPoint(x: 100, y: 50)
        )
        XCTAssertEqual(
            ActionsRingOverlayController.panelOrigin(
                cursor: CGPoint(x: 900, y: 650),
                side: 420,
                visibleFrame: visibleFrame
            ),
            CGPoint(x: 480, y: 230)
        )

        let smallerThanPanel = CGRect(x: -200, y: 25, width: 320, height: 300)
        XCTAssertEqual(
            ActionsRingOverlayController.panelOrigin(
                cursor: CGPoint(x: 0, y: 100),
                side: 420,
                visibleFrame: smallerThanPanel
            ),
            smallerThanPanel.origin,
            "窗口大于屏幕可见区域时也不能被计算到屏幕左下边界之外"
        )
    }

    func testRemoteCanvasMatchesReferenceProductBand() {
        let contentHeight: CGFloat = 728
        let detailHeaderHeight: CGFloat = 112
        let titlebarHeight: CGFloat = 32
        let viewportHeight = contentHeight - detailHeaderHeight
        let imageHeight = RemoteCanvasMetrics.imageHeight(for: viewportHeight)

        XCTAssertEqual(imageHeight, 462)
        XCTAssertEqual(
            imageHeight * RemoteCanvasMetrics.productContentScale * (1_639.0 / 1_784.0),
            imageHeight,
            accuracy: 0.001,
            "透明裁边后的实际产品高度应填满参考产品带"
        )
        XCTAssertEqual(
            imageHeight * RemoteCanvasMetrics.perspectiveContentScale * (1_532.0 / 1_556.0),
            imageHeight,
            accuracy: 0.001,
            "斜视角素材的实际产品高度应填满同一参考产品带"
        )
        XCTAssertEqual(RemoteCanvasMetrics.perspectiveAspectRatio, 388.0 / 1_556.0)
        XCTAssertEqual(
            RemoteCanvasMetrics.perspectiveAspectRatio
                * RemoteCanvasMetrics.perspectiveHorizontalScale,
            0.2743,
            accuracy: 0.001,
            "斜视角素材应恢复到真实遥控器的宽高比例"
        )
        XCTAssertEqual(
            titlebarHeight + detailHeaderHeight + RemoteCanvasMetrics.productViewportTop,
            178.4,
            accuracy: 0.001
        )
        XCTAssertEqual(
            titlebarHeight + detailHeaderHeight + RemoteCanvasMetrics.productViewportTop + imageHeight,
            640.4,
            accuracy: 0.001
        )
        XCTAssertEqual(RemoteCanvasMetrics.calloutViewportTop, 64)
        XCTAssertEqual(RemoteCanvasMetrics.calloutLayoutHeight, 449)
        XCTAssertEqual(RemoteCanvasMetrics.calloutVerticalPadding, 10)
        XCTAssertEqual(RemoteCanvasMetrics.calloutMinimumHeight, 58.4)
        XCTAssertEqual(RemoteCanvasMetrics.calloutTextYOffset, 0)
        XCTAssertEqual(RemoteCanvasMetrics.calloutColumnWidth, 180)
        XCTAssertEqual(RemoteCanvasMetrics.calloutInnerGap, 88)
        XCTAssertEqual(DeviceDetailLayoutMetrics.profileIconOpticalYOffset, 0)
    }

    func testPerspectiveHotspotsFollowTheRenderedHardwarePlane() throws {
        let power = try XCTUnwrap(RemoteButtonSlot.demoSlots.first(where: { $0.id == "power" }))
        let up = try XCTUnwrap(RemoteButtonSlot.demoSlots.first(where: { $0.id == "up" }))
        let left = try XCTUnwrap(RemoteButtonSlot.demoSlots.first(where: { $0.id == "left" }))
        let down = try XCTUnwrap(RemoteButtonSlot.demoSlots.first(where: { $0.id == "down" }))
        let menu = try XCTUnwrap(RemoteButtonSlot.demoSlots.first(where: { $0.id == "menu" }))

        let powerPoint = PerspectiveHotspotPlacement.point(for: power)
        XCTAssertEqual(powerPoint.x * 388, 83, accuracy: 0.001)
        XCTAssertEqual(powerPoint.y * 1_556, 150, accuracy: 0.001)

        let upTarget = PerspectiveHotspotPlacement.targetPoint(for: up)
        let leftTarget = PerspectiveHotspotPlacement.targetPoint(for: left)
        let downTarget = PerspectiveHotspotPlacement.targetPoint(for: down)
        XCTAssertEqual(upTarget.y * 1_556, 281, accuracy: 0.001)
        XCTAssertEqual(leftTarget.x * 388, 64, accuracy: 0.001)
        XCTAssertEqual(downTarget.y * 1_556, 552, accuracy: 0.001)

        let renderedSize = CGSize(
            width: 388 * RemoteCanvasMetrics.perspectiveHorizontalScale,
            height: 1_556
        )
        let leftOffset = PerspectiveHotspotPlacement.targetOffset(
            for: left,
            remoteSize: renderedSize
        )
        XCTAssertEqual(leftOffset.width, -108 * 1.10, accuracy: 0.001)

        let topProjection = PerspectiveHotspotPlacement.markerProjection(for: power)
        let bottomProjection = PerspectiveHotspotPlacement.markerProjection(for: menu)
        XCTAssertGreaterThan(topProjection.verticalScale, 1)
        XCTAssertLessThan(topProjection.rotationDegrees, 0)
        XCTAssertGreaterThan(bottomProjection.rotationDegrees, 0)
    }

    func testHomeDeviceCardKeepsTheReferenceProductHierarchyForSilverHardware() {
        XCTAssertEqual(HomeDeviceCardMetrics.connectedProductOpacity, 1, accuracy: 0.001)
        XCTAssertEqual(HomeDeviceCardMetrics.unavailableProductOpacity, 0.4, accuracy: 0.001)
        XCTAssertEqual(HomeDeviceCardMetrics.productFrameHeight, 228, accuracy: 0.001)
        XCTAssertEqual(HomeDeviceCardMetrics.idleProductOffsetY, 19, accuracy: 0.001)
        XCTAssertEqual(HomeDeviceCardMetrics.hoveredProductOffsetY, 7, accuracy: 0.001)
        XCTAssertLessThan(
            HomeDeviceCardMetrics.unavailableProductOpacity,
            HomeDeviceCardMetrics.connectedProductOpacity
        )
        XCTAssertEqual(
            HomeDeviceCardMetrics.idleProductOffsetY
                - HomeDeviceCardMetrics.hoveredProductOffsetY,
            12,
            accuracy: 0.001,
            "Options+ hover 只把产品向上移动 12 pt"
        )
        XCTAssertEqual(BatteryConnectionStatusMetrics.compactControlWidth, 54)
        XCTAssertEqual(BatteryConnectionStatusMetrics.reportedControlWidth, 103)
        XCTAssertEqual(BatteryConnectionStatusMetrics.controlHeight, 40)
        XCTAssertEqual(BatteryConnectionStatusMetrics.horizontalPadding, 6)
        XCTAssertEqual(BatteryConnectionStatusMetrics.reportedValueSpacing, 6.5)
        XCTAssertEqual(BatteryConnectionStatusMetrics.iconSlotWidth, 26)
        XCTAssertEqual(BatteryConnectionStatusMetrics.cornerRadius, 4)
    }

    func testHomeGreetingMatchesReferenceDayParts() {
        XCTAssertEqual(HomeGreeting.title(forHour: 0), "早上好")
        XCTAssertEqual(HomeGreeting.title(forHour: 4), "早上好")
        XCTAssertEqual(HomeGreeting.title(forHour: 11), "早上好")
        XCTAssertEqual(HomeGreeting.title(forHour: 12), "下午好")
        XCTAssertEqual(HomeGreeting.title(forHour: 17), "下午好")
        XCTAssertEqual(HomeGreeting.title(forHour: 18), "晚上好")
        XCTAssertEqual(HomeGreeting.title(forHour: 23), "晚上好")
    }

    func testDeviceActionPresentationLocalizesReferenceEditorLabels() throws {
        let lock = try XCTUnwrap(RemoteAction.catalog.first(where: { $0.id == "lock" }))
        let screenshot = try XCTUnwrap(RemoteAction.catalog.first(where: { $0.id == "screenshot" }))
        let notes = try XCTUnwrap(RemoteAction.catalog.first(where: { $0.id == "launch-notes" }))

        XCTAssertEqual(lock.title, "Lock Workstation")
        XCTAssertEqual(lock.devicePresentationTitle, "锁定屏幕")
        XCTAssertEqual(screenshot.devicePresentationTitle, "区域截图")
        XCTAssertEqual(notes.title, "New Note")
        XCTAssertEqual(notes.devicePresentationTitle, "新建备忘录")
    }

    @MainActor
    func testSystemExecutorPublishesActionsRingRequest() async {
        let expectation = expectation(description: "收到 Actions Ring 显示请求")
        let token = NotificationCenter.default.addObserver(
            forName: .showActionsRingRequested,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        let executor = SystemActionExecutor()
        defer { withExtendedLifetime(executor) {} }
        executor.execute(.showActionsRing)

        await fulfillment(of: [expectation], timeout: 1)
    }

    @MainActor
    func testAddDeviceFlowEntersAndLeavesConnectionPicker() {
        let store = AppStore(runtimeServicesEnabled: false)
        store.openDevice(.remote2Pro)

        store.beginAddingDevice()

        XCTAssertTrue(store.showsConnectionTypePicker)
        XCTAssertNil(store.activeDeviceID)
        XCTAssertEqual(store.activeSection, .devices)

        store.cancelAddingDevice()

        XCTAssertFalse(store.showsConnectionTypePicker)

        store.beginAddingDevice()
        store.connectWithBluetooth()

        XCTAssertTrue(store.showsConnectionTypePicker)

        store.selectSection(.settings)

        XCTAssertFalse(store.showsConnectionTypePicker)
        XCTAssertEqual(store.activeSection, .settings)
    }

    @MainActor
    func testRemovingManagedDevicePersistsAndCanBeAddedAgain() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiCoding-ManagedDevice-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configurationStore = LocalConfigurationStore(
            fileURL: directory.appendingPathComponent("config.json")
        )
        let store = AppStore(
            configurationStore: configurationStore,
            runtimeServicesEnabled: false,
            initialDeviceSnapshot: BluetoothDeviceSnapshot(
                batteryLevel: 72,
                firmwareVersion: "2671"
            )
        )
        let previousOKAction = store.action(for: "ok")?.id
        store.openDevice(.remote2Pro)

        store.removeManagedDevice(openBluetoothSettings: false)

        XCTAssertFalse(store.remoteIsManaged)
        XCTAssertNil(store.activeDeviceID)
        XCTAssertFalse(store.devicePresent)
        XCTAssertEqual(store.connectionState, .disconnected)
        XCTAssertNil(store.batteryLevel)
        XCTAssertTrue(store.inputServiceEnabled)
        XCTAssertEqual(store.action(for: "ok")?.id, previousOKAction)

        store.backendCoordinator.onConnectionChanged?(true)
        store.backendCoordinator.onInputEvent?(
            RemoteInputEvent(
                deviceID: RemoteDevice.remote2Pro.id,
                slotID: "ok",
                phase: .began,
                timestamp: Date()
            )
        )
        XCTAssertFalse(store.devicePresent, "移除后到达的旧连接回调不能重新激活设备")
        XCTAssertNil(store.selectedSlotID, "移除后到达的旧按键事件必须被忽略")

        let reloaded = AppStore(
            configurationStore: configurationStore,
            runtimeServicesEnabled: false
        )
        XCTAssertFalse(reloaded.remoteIsManaged)
        reloaded.openDevice(.remote2Pro)
        XCTAssertTrue(reloaded.showsConnectionTypePicker)
        XCTAssertNil(reloaded.activeDeviceID)

        reloaded.finishAddingDevice()
        XCTAssertTrue(reloaded.remoteIsManaged)
        let restored = AppStore(
            configurationStore: configurationStore,
            runtimeServicesEnabled: false
        )
        XCTAssertTrue(restored.remoteIsManaged)
        XCTAssertEqual(restored.action(for: "ok")?.id, previousOKAction)
    }

    @MainActor
    func testDisconnectedDeviceCanBeOpenedForOfflineConfiguration() {
        let store = AppStore()
        store.connectionState = .disconnected

        store.openDevice(.remote2Pro)

        XCTAssertEqual(store.activeDeviceID, RemoteDevice.remote2Pro.id)
        XCTAssertNil(store.selectedSlotID)
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
        engine.debounceMilliseconds = 0
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

    @MainActor
    func testGestureEngineSuppressesInputBounceWithinConfiguredWindow() {
        let engine = RemoteGestureEngine()
        engine.debounceMilliseconds = 30
        engine.hasBinding = { _, _ in false }
        var resolved: [ResolvedRemoteTrigger] = []
        engine.onResolvedTrigger = { resolved.append($0) }

        let start = Date()
        engine.handle(RemoteInputEvent(deviceID: "test", slotID: "ok", phase: .began, timestamp: start))
        engine.handle(RemoteInputEvent(deviceID: "test", slotID: "ok", phase: .ended, timestamp: start.addingTimeInterval(0.01)))
        engine.handle(RemoteInputEvent(deviceID: "test", slotID: "ok", phase: .began, timestamp: start.addingTimeInterval(0.02)))
        engine.handle(RemoteInputEvent(deviceID: "test", slotID: "ok", phase: .ended, timestamp: start.addingTimeInterval(0.025)))
        engine.handle(RemoteInputEvent(deviceID: "test", slotID: "ok", phase: .began, timestamp: start.addingTimeInterval(0.05)))
        engine.handle(RemoteInputEvent(deviceID: "test", slotID: "ok", phase: .ended, timestamp: start.addingTimeInterval(0.06)))

        XCTAssertEqual(resolved.map(\.trigger), [.tap, .tap])
    }
}

@MainActor
private final class RecordingActionExecutor: ActionExecuting {
    private(set) var commands: [ActionCommand] = []

    func execute(_ command: ActionCommand) {
        commands.append(command)
    }
}

private final class RecordingDeviceKeyRemapper: DeviceKeyRemapping {
    var onLog: ((String) -> Void)?
    var onEvent: ((RemoteInputEvent) -> Void)?
    var activeRemappedSlotIDs: Set<String> = []
    private(set) var installCount = 0
    private(set) var uninstallCount = 0

    func install() -> Bool {
        installCount += 1
        return true
    }

    func uninstall() {
        uninstallCount += 1
    }
}

private final class ControllableRemoteInputService: RemoteInputServicing {
    var onEvent: ((RemoteInputEvent) -> Void)?
    var onConnectionChanged: ((Bool) -> Void)?
    var onUnknownUsage: ((UInt32, Bool) -> Void)?

    func start() throws {}
    func stop() {}

    func emitConnection(_ connected: Bool) {
        onConnectionChanged?(connected)
    }
}
