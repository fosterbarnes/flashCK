// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "flashCK",
    platforms: [.macOS(.v12)],
    targets: [
        .target(name: "flashCKCore", path: "src/flashCKCore"),
        .executableTarget(name: "flashCK", dependencies: ["flashCKCore"], path: "src/flashCK"),
        .testTarget(name: "flashCKTests", dependencies: ["flashCKCore"], path: "src/flashCKTests"),
    ]
)
