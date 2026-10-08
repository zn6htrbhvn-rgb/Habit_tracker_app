// swift-tools-version: 5.9

// This is the Swift Playgrounds (iPad) flavour of ZenHabit.
// The sources are identical to ios/ZenHabit; keep the two folders in sync.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "ZenHabit",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "ZenHabit",
            targets: ["AppModule"],
            bundleIdentifier: "app.zenhabit.ZenHabit",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .asset("AppIcon"),
            accentColor: .asset("AccentColor"),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
