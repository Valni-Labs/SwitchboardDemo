// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwitchboardDemo",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../Switchboard"),
    ],
    targets: [
        .executableTarget(
            name: "SwitchboardDemo",
            dependencies: [
                .product(name: "Switchboard", package: "Switchboard"),
                .product(name: "SwitchboardLocal", package: "Switchboard"),
            ]
        ),
        .testTarget(
            name: "SwitchboardDemoTests",
            dependencies: ["SwitchboardDemo"]
        ),
    ]
)
