// swift-tools-version: 5.9
import PackageDescription

// DO NOT MODIFY THIS FILE - managed by Capacitor CLI commands
let package = Package(
    name: "CapApp-SPM",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "CapApp-SPM",
            targets: ["CapApp-SPM"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", exact: "8.0.0"),
        .package(name: "CapacitorApp", path: "../../../node_modules/.bun/@capacitor+app@8.1.0+15e98482558ccfe6/node_modules/@capacitor/app"),
        .package(name: "CapacitorHaptics", path: "../../../node_modules/.bun/@capacitor+haptics@8.0.2+15e98482558ccfe6/node_modules/@capacitor/haptics"),
        .package(name: "CapacitorKeyboard", path: "../../../node_modules/.bun/@capacitor+keyboard@8.0.3+15e98482558ccfe6/node_modules/@capacitor/keyboard"),
        .package(name: "CapacitorStatusBar", path: "../../../node_modules/.bun/@capacitor+status-bar@8.0.2+15e98482558ccfe6/node_modules/@capacitor/status-bar"),
        .package(name: "CapgoCapacitorLlm", path: "../../../node_modules/.bun/@capgo+capacitor-llm@file+..+fc1b02bbafc7d0ef/node_modules/@capgo/capacitor-llm"),
        .package(name: "CapgoCapacitorUpdater", path: "../../../node_modules/.bun/@capgo+capacitor-updater@8.47.10+15e98482558ccfe6/node_modules/@capgo/capacitor-updater"),
        .package(name: "CapacitorSplashScreen", path: "../../../node_modules/.bun/@capacitor+splash-screen@8.0.1+15e98482558ccfe6/node_modules/@capacitor/splash-screen")
    ],
    targets: [
        .target(
            name: "CapApp-SPM",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm"),
                .product(name: "CapacitorApp", package: "CapacitorApp"),
                .product(name: "CapacitorHaptics", package: "CapacitorHaptics"),
                .product(name: "CapacitorKeyboard", package: "CapacitorKeyboard"),
                .product(name: "CapacitorStatusBar", package: "CapacitorStatusBar"),
                .product(name: "CapgoCapacitorLlm", package: "CapgoCapacitorLlm"),
                .product(name: "CapgoCapacitorUpdater", package: "CapgoCapacitorUpdater"),
                .product(name: "CapacitorSplashScreen", package: "CapacitorSplashScreen")
            ]
        )
    ]
)
