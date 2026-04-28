// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuickTranslate",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "QuickTranslate",
            path: "QuickTranslate",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
            ]
        )
    ]
)
