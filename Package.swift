// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwitchboardDemo",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/valni-labs/switchboard-swift", from: "0.13.0"),
    ],
    targets: [
        .executableTarget(
            name: "SwitchboardDemo",
            dependencies: [
                .product(name: "Switchboard", package: "switchboard-swift"),
                .product(name: "SwitchboardLocal", package: "switchboard-swift"),
            ]
        ),
        .testTarget(
            name: "SwitchboardDemoTests",
            dependencies: ["SwitchboardDemo"]
        ),
    ]
)
