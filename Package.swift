// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "XiaomiRemoteStudio",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "XiaomiRemoteStudio", targets: ["XiaomiRemoteStudio"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/JakubMazur/lucide-icons-swift.git",
            exact: "1.29.0"
        )
    ],
    targets: [
        .executableTarget(
            name: "XiaomiRemoteStudio",
            dependencies: [
                .product(name: "LucideIcons", package: "lucide-icons-swift")
            ],
            path: "Sources/XiaomiRemoteStudio",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "XiaomiRemoteStudioTests",
            dependencies: ["XiaomiRemoteStudio"]
        )
    ]
)
