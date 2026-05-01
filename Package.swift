// swift-tools-version: 5.9
import PackageDescription

// Jeff is primarily an Xcode app target — it needs Info.plist, entitlements,
// and code signing for camera/microphone/speech.
//
// This Package.swift exposes the pure-Swift logic as `JeffCore` so the
// non-UI pieces (models + services) can build on CI without Xcode. The
// shipping app is built from an Xcode project that references the same
// source tree.
let package = Package(
    name: "Jeff",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "JeffCore", targets: ["JeffCore"])
    ],
    targets: [
        .target(
            name: "JeffCore",
            path: "Jeff",
            sources: ["Models", "Services"]
        )
    ]
)
