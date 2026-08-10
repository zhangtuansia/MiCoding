import AppKit
import os
import SwiftUI

private let appLifecycleLogger = Logger(
    subsystem: "io.xiaomiremote.studio",
    category: "Lifecycle"
)

enum MainWindowLayoutMetrics {
    static let contentSize = NSSize(width: 1_180, height: 728)
    static let frameSize = NSSize(width: 1_180, height: 760)
    // Options+ exposes a fixed 1,180 x 760 main window: close and minimize are
    // available, while the green zoom/full-screen control is disabled. Keeping
    // the same contract also prevents the reference-tuned layout from being
    // stretched into unsupported sizes.
    static let styleMask: NSWindow.StyleMask = [
        .titled,
        .closable,
        .miniaturizable,
        .fullSizeContentView
    ]
    static let fallbackTopInset: CGFloat = 80
    static let fallbackLeadingInset: CGFloat = 80
    static let minimumVisibleWidth: CGFloat = 160
    static let minimumVisibleHeight: CGFloat = 80

    static func isUsable(frame: NSRect, on screenFrames: [NSRect]) -> Bool {
        screenFrames.contains { screenFrame in
            let intersection = frame.intersection(screenFrame)
            return intersection.width >= minimumVisibleWidth
                && intersection.height >= minimumVisibleHeight
        }
    }

    static func fallbackTopLeft(in screenFrame: NSRect) -> NSPoint {
        NSPoint(
            x: screenFrame.minX + fallbackLeadingInset,
            y: screenFrame.maxY - fallbackTopInset
        )
    }
}

@main
@MainActor
enum XiaomiRemoteStudioApp {
    static func main() {
        // Drive the app with AppKit directly. A Settings-only SwiftUI lifecycle
        // can miss its delegate launch callback on macOS 26, leaving a healthy
        // background process with no window. The views remain SwiftUI; AppKit
        // simply owns their single, reference-sized host window deterministically.
        let application = NSApplication.shared
        let applicationDelegate = MiCodingApplicationDelegate()
        application.setActivationPolicy(.regular)
        application.delegate = applicationDelegate
        // `NSApplication.run()` does not reliably deliver the delegate's
        // did-finish-launching callback for this executable-style SwiftPM app
        // on macOS 26. Finish AppKit's launch phase explicitly, then perform
        // the idempotent presentation step ourselves so a live process can
        // never be left with zero windows.
        application.finishLaunching()
        applicationDelegate.presentMainWindow()
        // macOS 26 can run persistent-window restoration as `run()` starts and
        // order out a window presented immediately above. Reassert visibility
        // on the first main-loop turn, after restoration has completed.
        DispatchQueue.main.async { [applicationDelegate] in
            applicationDelegate.presentMainWindow()
        }
        withExtendedLifetime(applicationDelegate) {
            application.run()
        }
    }
}

@MainActor
final class MiCodingApplicationDelegate: NSObject, NSApplicationDelegate {
    private lazy var store = AppStore()
    private var mainWindow: NSWindow?
    private var preparedApplication = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        presentMainWindow()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showMainWindow()
        return true
    }

    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        showMainWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func showSettings() {
        store.selectSection(.settings)
        showMainWindow()
    }

    func presentMainWindow() {
        if !preparedApplication {
            NSApp.mainMenu = makeMainMenu()
            preparedApplication = true
        }
        showMainWindow()
    }

    /// Options+ keeps the macOS menu bar intentionally small: its application
    /// menu and one Edit menu. Building the same hierarchy avoids the default
    /// SwiftUI View/Window/Help menus appearing above every reference-aligned
    /// screen, while retaining the standard text-editing shortcuts.
    func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu(title: "MainMenu")

        let applicationItem = NSMenuItem(title: "MiCoding", action: nil, keyEquivalent: "")
        mainMenu.addItem(applicationItem)
        mainMenu.setSubmenu(makeApplicationMenu(), for: applicationItem)

        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        mainMenu.addItem(editItem)
        mainMenu.setSubmenu(makeEditMenu(), for: editItem)

        return mainMenu
    }

    private func makeApplicationMenu() -> NSMenu {
        let menu = NSMenu(title: "MiCoding")

        let aboutItem = NSMenuItem(
            title: "关于 MiCoding",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        aboutItem.target = NSApp
        menu.addItem(aboutItem)
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "设置…",
            action: #selector(showSettingsFromMenu(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())

        let hideItem = NSMenuItem(
            title: "隐藏 MiCoding",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        hideItem.target = NSApp
        menu.addItem(hideItem)

        let hideOthersItem = NSMenuItem(
            title: "隐藏其他",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        hideOthersItem.target = NSApp
        menu.addItem(hideOthersItem)

        let showAllItem = NSMenuItem(
            title: "全部显示",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        showAllItem.target = NSApp
        menu.addItem(showAllItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "退出 MiCoding",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        menu.addItem(quitItem)
        return menu
    }

    private func makeEditMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.addItem(editItem(title: "撤销", action: "undo:", key: "z"))

        let redoItem = editItem(title: "重做", action: "redo:", key: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(redoItem)
        menu.addItem(.separator())
        menu.addItem(editItem(title: "剪切", action: "cut:", key: "x"))
        menu.addItem(editItem(title: "复制", action: "copy:", key: "c"))
        menu.addItem(editItem(title: "粘贴", action: "paste:", key: "v"))
        menu.addItem(editItem(title: "全选", action: "selectAll:", key: "a"))
        return menu
    }

    private func editItem(title: String, action: String, key: String) -> NSMenuItem {
        NSMenuItem(title: title, action: Selector((action)), keyEquivalent: key)
    }

    @objc private func showSettingsFromMenu(_ sender: Any?) {
        showSettings()
    }

    private func showMainWindow() {
        let window = mainWindow ?? makeMainWindow()

        ensureWindowIsVisible(window)

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        appLifecycleLogger.info(
            "Main window requested visible=\(window.isVisible) key=\(window.isKeyWindow) windows=\(NSApp.windows.count) frame=\(NSStringFromRect(window.frame), privacy: .public)"
        )
    }

    private func makeMainWindow() -> NSWindow {
        let contentSize = MainWindowLayoutMetrics.contentSize
        let rootView = AppShellView()
            .environmentObject(store)
            .frame(minWidth: contentSize.width, minHeight: contentSize.height)
            .preferredColorScheme(store.preferredColorScheme)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: MainWindowLayoutMetrics.styleMask,
            backing: .buffered,
            defer: false
        )
        window.title = "MiCoding"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unifiedCompact
        window.contentMinSize = contentSize
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: rootView)

        let autosaveName = "MiCodingMainWindow"
        let restoredFrame = window.setFrameUsingName(autosaveName)
        let restoredTopLeft = NSPoint(x: window.frame.minX, y: window.frame.maxY)
        // Window restoration also restores an old size. A full-size titlebar
        // normally grows a 728 pt layout area into a 760 pt outer frame during
        // AppKit's first layout pass, but that pass is deferred while macOS is
        // locked. Set the outer frame explicitly so launch geometry never
        // depends on an unlock or activation event.
        window.setFrame(
            NSRect(origin: window.frame.origin, size: MainWindowLayoutMetrics.frameSize),
            display: false
        )
        if restoredFrame {
            window.setFrameTopLeftPoint(restoredTopLeft)
        }
        ensureWindowIsVisible(window)
        window.setFrameAutosaveName(autosaveName)

        mainWindow = window
        appLifecycleLogger.info(
            "Main window created visible=\(window.isVisible) windows=\(NSApp.windows.count) frame=\(NSStringFromRect(window.frame), privacy: .public)"
        )
        return window
    }

    private func ensureWindowIsVisible(_ window: NSWindow) {
        let screens = NSScreen.screens
        let screenFrames = screens.map(\.frame)
        guard !MainWindowLayoutMetrics.isUsable(frame: window.frame, on: screenFrames),
              let targetScreen = NSScreen.main ?? screens.first else {
            return
        }
        window.setFrameTopLeftPoint(
            MainWindowLayoutMetrics.fallbackTopLeft(in: targetScreen.frame)
        )
    }
}
