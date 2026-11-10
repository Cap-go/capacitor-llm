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
            url: "https://github.com/google-ai-edge/LiteRT-LM/releases/download/v0.19.1/CLiteRTLM.xcframework.zip",
            checksum: "21cf294b3dfdd9c8166b0f7934ed392d5c69c8bfa57cd1a20e341a7d16874017"
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
