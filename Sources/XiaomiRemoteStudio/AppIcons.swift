import AppKit
import LucideIcons
import SwiftUI

/// MiCoding uses Lucide's 24 × 24 outline language for application chrome.
/// RemoteButtonSlot symbols are mapped too, but the photographed hardware keeps
/// its original product markings instead of being redrawn with UI icons.
enum AppIconRegistry {
    static let lucideIDByLegacySymbol: [String: String] = [
        // Navigation and application chrome
        "av.remote": "radio-receiver",
        "bolt.horizontal.circle": "workflow",
        "gearshape": "settings",
        "plus": "plus",
        "chevron.left": "chevron-left",
        "chevron.right": "chevron-right",
        "chevron.up": "chevron-up",
        "chevron.down": "chevron-down",
        "button.programmable": "circle-dot",
        "slider.horizontal.3": "sliders-horizontal",
        "globe": "globe",
        "safari.fill": "compass",
        "music.note": "music",
        "scissors": "scissors",

        // Actions and feedback
        "magnifyingglass": "search",
        "xmark": "x",
        "xmark.circle.fill": "circle-x",
        "calendar": "calendar",
        "checkmark": "check",
        "checkmark.circle.fill": "circle-check",
        "play.fill": "play",
        "playpause.fill": "circle-play",
        "forward.end.fill": "skip-forward",
        "speaker.plus.fill": "volume-2",
        "speaker.minus.fill": "volume-1",
        "speaker.slash.fill": "volume-x",
        "rectangle.3.group": "panels-top-left",
        "macwindow": "monitor",
        "lock.fill": "lock",
        "viewfinder": "scan",
        "moon.stars.fill": "moon-star",
        "video.fill": "video",
        "square.and.pencil": "square-pen",
        "wand.and.stars": "wand-sparkles",
        "lock.shield.fill": "shield-check",
        "checkmark.shield.fill": "shield-check",
        "dot.radiowaves.left.and.right": "radio",

        // Physical-button semantics used by models and accessibility previews
        "power": "power",
        "mic.fill": "mic",
        "circle.fill": "circle-dot",
        "arrow.uturn.backward": "undo-2",
        "house.fill": "house",
        "line.3.horizontal": "menu",
        "minus": "minus",
        "tv.fill": "tv"
    ]

    static let interfaceSymbols: Set<String> = [
        "av.remote", "bolt.horizontal.circle", "gearshape", "plus",
        "chevron.left", "chevron.down", "button.programmable",
        "slider.horizontal.3", "magnifyingglass", "xmark", "xmark.circle.fill", "calendar",
        "checkmark", "checkmark.circle.fill", "play.fill",
        "wand.and.stars", "lock.shield.fill", "checkmark.shield.fill",
        "dot.radiowaves.left.and.right"
    ]

    static func lucideID(for symbol: String) -> String {
        lucideIDByLegacySymbol[symbol] ?? symbol
    }

    static func contains(_ symbol: String) -> Bool {
        LucideAssetLoader.image(named: lucideID(for: symbol)) != nil
    }
}

private enum LucideAssetLoader {
    // Keep the package product linked while using its raw SwiftPM resource
    // layout, which is more reliable than named assets in command-line builds.
    private static let packageLinkAnchor: Lucide.Type = Lucide.self

    private static let bundleURL: URL? = {
        _ = packageLinkAnchor

        var roots: [URL] = [Bundle.module.bundleURL.deletingLastPathComponent()]
        if let mainResources = Bundle.main.resourceURL {
            roots.append(mainResources)
        }
        roots.append(Bundle.main.bundleURL.deletingLastPathComponent())

        return roots
            .map { $0.appendingPathComponent("LucideIcons_LucideIcons.bundle", isDirectory: true) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }()

    static func image(named iconID: String) -> NSImage? {
        if let image = NSImage.image(lucideId: iconID) {
            return image
        }

        guard let bundleURL else { return nil }
        let imageURL = bundleURL
            .appendingPathComponent("icons.xcassets", isDirectory: true)
            .appendingPathComponent("\(iconID).imageset", isDirectory: true)
            .appendingPathComponent("\(iconID).pdf")
        return NSImage(contentsOf: imageURL)
    }
}

struct AppIcon: View {
    let symbol: String
    var size: CGFloat = AppIconSize.row

    var body: some View {
        Group {
            if let image = Self.image(for: symbol) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
            } else {
                MissingAppIcon()
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private static let cache = NSCache<NSString, NSImage>()

    private static func image(for symbol: String) -> NSImage? {
        let iconID = AppIconRegistry.lucideID(for: symbol)
        if let cached = cache.object(forKey: iconID as NSString) {
            return cached
        }
        guard let source = LucideAssetLoader.image(named: iconID),
              let image = source.copy() as? NSImage else {
            return nil
        }
        image.isTemplate = true
        cache.setObject(image, forKey: iconID as NSString)
        return image
    }
}

private struct MissingAppIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(lineWidth: 1.6)

            Capsule()
                .frame(width: 2, height: 5)
                .offset(y: -3)

            Circle()
                .frame(width: 2, height: 2)
                .offset(y: 4)
        }
    }
}
