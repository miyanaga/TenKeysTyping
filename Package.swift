// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TenKeysTyping",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TenKeysTyping",
            path: "Sources/TenKeysTyping"
        )
    ]
)
