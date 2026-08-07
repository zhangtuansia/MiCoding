import SwiftUI

@main
struct XiaomiRemoteStudioApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup("MiCoding") {
            AppShellView()
                .environmentObject(store)
                .frame(minWidth: 1_080, minHeight: 700)
                .preferredColorScheme(store.preferredColorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .defaultSize(width: 1_280, height: 820)
    }
}
