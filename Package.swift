// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TunnelBar",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "TunnelBar", targets: ["TunnelBar"])],
    targets: [
        .target(name: "TunnelCore"),
        .executableTarget(name: "TunnelBar", dependencies: ["TunnelCore"]),
        .testTarget(name: "TunnelCoreTests", dependencies: ["TunnelCore"])
    ]
)
