// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CapgoCapacitorLlm",
    platforms: [.iOS(.v17)],
    products: [
        .library(
            name: "CapgoCapacitorLlm",
            targets: ["LLMPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "8.0.0"),
        .package(url: "https://github.com/pytorch/executorch.git", branch: "swiftpm-1.2.0")
    ],
    targets: [
        .target(
            name: "LLMPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm"),
                .product(name: "executorch_llm", package: "executorch"),
                .product(name: "backend_xnnpack", package: "executorch"),
                .product(name: "kernels_llm", package: "executorch"),
                .product(name: "kernels_optimized", package: "executorch"),
                .product(name: "kernels_quantized", package: "executorch"),
                .product(name: "kernels_torchao", package: "executorch")
            ],
            path: "ios/Sources/LLMPlugin"),
        .testTarget(
            name: "LLMPluginTests",
            dependencies: ["LLMPlugin"],
            path: "ios/Tests/LLMPluginTests")
    ]
)
