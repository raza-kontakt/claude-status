// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ClaudeLight",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "claude-light-app", targets: ["claude-light-app"]),
        .executable(name: "claude-light-hook", targets: ["claude-light-hook"]),
        .executable(name: "claude-light-install", targets: ["claude-light-install"]),
    ],
    targets: [
        .target(name: "ClaudeLightCore", swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "claude-light-app", dependencies: ["ClaudeLightCore"], swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "claude-light-hook", dependencies: ["ClaudeLightCore"], swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "claude-light-install", dependencies: ["ClaudeLightCore"], swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "ClaudeLightCoreTests", dependencies: ["ClaudeLightCore"], swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
