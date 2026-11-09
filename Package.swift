// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sightline",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "Sightline")
    ]
)
