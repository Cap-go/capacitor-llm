// swift-tools-version: 5.9
import PackageDescription

// IMPORTANT: This Package.swift is for Swift Package Manager only.
// If you use CocoaPods, the CapgoCapacitorLlm.podspec will be used instead,
// which includes MediaPipe dependencies. Both approaches are fully supported:
//
// - SPM: Provides Apple Intelligence support (iOS 18.2+)
// - CocoaPods: Provides both Apple Intelligence AND MediaPipe custom models
//
// The Swift code uses conditional compilation (#if COCOAPODS) to detect
// which dependency manager is being used and enables appropriate features.

let package = Package(
    name: "CapgoLLM",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "CapgoLLM",
            targets: ["LLMPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "7.0.0")
        // Note: SwiftTasksGenAI contains unsafe build flags and cannot be used with SPM
        // For MediaPipe GenAI support, use CocoaPods instead (see CapgoCapacitorLlm.podspec)
        // See: https://github.com/paescebu/SwiftTasksGenAI
        // .package(url: "https://github.com/paescebu/SwiftTasksGenAI.git", from: "0.10.0")
    ],
    targets: [
        .target(
            name: "LLMPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm")
                // SwiftTasksGenAI cannot be added due to unsafe build flags
                // Use CocoaPods for MediaPipe GenAI support
            ],
            path: "ios/Sources/LLMPlugin"),
        .testTarget(
            name: "LLMPluginTests",
            dependencies: ["LLMPlugin"],
            path: "ios/Tests/LLMPluginTests")
    ]
)
