// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "ViaSix",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ViaSixCore", targets: ["ViaSixCore"]),
        .library(
            name: "ViaSixPrivilegedProtocol",
            targets: ["ViaSixPrivilegedProtocol"]
        ),
        .library(
            name: "ViaSixTunHelperSupport",
            targets: ["ViaSixTunHelperSupport"]
        ),
        .executable(name: "ViaSix", targets: ["ViaSixApp"]),
        .executable(name: "ViaSixTunHelper", targets: ["ViaSixTunHelper"]),
    ],
    targets: [
        .target(
            name: "ViaSixPrivilegedProtocol",
            linkerSettings: [
                .linkedFramework("Security")
            ]
        ),
        .target(
            name: "ViaSixCore",
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "ViaSixTunHelperSupport",
            dependencies: ["ViaSixPrivilegedProtocol"]
        ),
        .executableTarget(
            name: "ViaSixApp",
            dependencies: ["ViaSixCore", "ViaSixPrivilegedProtocol"],
            linkerSettings: [
                .linkedFramework("ServiceManagement")
            ]
        ),
        .executableTarget(
            name: "ViaSixTunHelper",
            dependencies: ["ViaSixPrivilegedProtocol", "ViaSixTunHelperSupport"]
        ),
        .testTarget(
            name: "ViaSixCoreTests",
            dependencies: ["ViaSixCore"]
        ),
        .testTarget(
            name: "ViaSixAppTests",
            dependencies: ["ViaSixApp", "ViaSixCore"]
        ),
        .testTarget(
            name: "ViaSixPrivilegedProtocolTests",
            dependencies: ["ViaSixPrivilegedProtocol"]
        ),
        .testTarget(
            name: "ViaSixTunHelperSupportTests",
            dependencies: ["ViaSixTunHelperSupport"]
        ),
    ]
)
