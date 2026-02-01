// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sightline",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "Sightline",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("IOSurface"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo")
            ]
        )
    ]
)
