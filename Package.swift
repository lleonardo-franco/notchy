// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Notchy",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Notchy", path: "Sources/Notchy")
    ]
)
