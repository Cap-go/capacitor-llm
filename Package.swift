// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CapgoCapacitorLlm",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "CapgoCapacitorLlm",
            targets: ["LLMPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "8.0.0")
    ],
    targets: [
        // Vendor the official Swift wrapper locally and fetch only the iOS xcframework.
        // The upstream repo checkout currently pulls non-iOS LFS blobs that break SwiftPM resolution here.
        .binaryTarget(
            name: "CLiteRTLM",
            url: "https://github.com/google-ai-edge/LiteRT-LM/releases/download/v0.13.0/CLiteRTLM.xcframework.zip",
            checksum: "af23c77b8eae3f1888fc0348c133af8a13f1e8a89f5788de7e38457f512e768a"
        ),
        .target(
            name: "LiteRTLM",
            dependencies: ["CLiteRTLM"],
            path: "ios/Sources/LiteRTLM",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-all_load"])
            ]
        ),
        .target(
            name: "LLMPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm"),
                "LiteRTLM"
            ],
            path: "ios/Sources/LLMPlugin"
        ),
        .testTarget(
            name: "LLMPluginTests",
            dependencies: ["LLMPlugin"],
            path: "ios/Tests/LLMPluginTests"
        )
    ]
)
