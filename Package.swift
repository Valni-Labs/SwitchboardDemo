// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwitchboardDemo",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/Benovi-Labs/switchboard-swift", from: "0.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "SwitchboardDemo",
            dependencies: [
                .product(name: "Switchboard", package: "switchboard-swift"),
            ]
        ),
        .testTarget(
            name: "SwitchboardDemoTests",
            dependencies: ["SwitchboardDemo"]
        ),
    ]
)
