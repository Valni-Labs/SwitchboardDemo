// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwitchboardDemo",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/Benovi-Labs/Switchboard", from: "0.1.0"),
        .package(url: "https://github.com/Benovi-Labs/Linecard", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "SwitchboardDemo",
            dependencies: [
                .product(name: "Switchboard", package: "Switchboard"),
                .product(name: "Linecard", package: "Linecard"),
            ]
        ),
        .testTarget(
            name: "SwitchboardDemoTests",
            dependencies: ["SwitchboardDemo"]
        ),
    ]
)
