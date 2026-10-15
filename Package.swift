// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TunnelBar",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "TunnelBar", targets: ["TunnelBar"]),
        .executable(name: "TunnelGuardian", targets: ["TunnelGuardian"])
    ],
    dependencies: [
        // Build the official library for our deployment target rather than linking
        // a toolchain-specific Testing.framework. Only the tests depend on it.
        // Swift Testing 6.0.3, pinned to its release commit. That release's macro
        // target uses compiler flags, which SwiftPM permits for revision pins.
        .package(url: "https://github.com/swiftlang/swift-testing.git",
                 revision: "18c42c19cac3fafd61cab1156d4088664b7424ae")
    ],
    targets: [
        .target(name: "TunnelCore"),
        .executableTarget(name: "TunnelBar", dependencies: ["TunnelCore"]),
        .executableTarget(name: "TunnelGuardian"),
        .testTarget(name: "TunnelCoreTests", dependencies: [
            "TunnelCore", .product(name: "Testing", package: "swift-testing")
        ])
    ],
    swiftLanguageModes: [.v5]
)
