// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SphereAnimation",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "SphereAnimation",
            targets: ["SphereAnimation"]
        ),
    ],
    targets: [
        // C target exposing ShaderTypes.h for both Swift and Metal
        .target(
            name: "CSphereAnimationTypes",
            path: "Sources/CSphereAnimationTypes",
            publicHeadersPath: "include"
        ),
        // Main Swift target
        .target(
            name: "SphereAnimation",
            dependencies: ["CSphereAnimationTypes"],
            path: "Sources/SphereAnimation",
            resources: [
                .process("Resources/Shaders.metal"),
                .copy("Resources/ShaderTypes.h")
            ]
        ),
    ]
)
