// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DailyBetter",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "DailyBetter", targets: ["DailyBetterApp"])],
    targets: [
        .executableTarget(
            name: "DailyBetterApp",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "DailyBetterAppTests",
            dependencies: ["DailyBetterApp"]
        )
    ]
)
