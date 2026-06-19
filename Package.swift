// swift-tools-version: 6.3
import Foundation
import PackageDescription

let packageDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let ghosttyMacOSLibraryDirectory = "\(packageDirectory)/Frameworks/GhosttyKit.xcframework/macos-arm64_x86_64"

// The upstream OmniWMTests target imports XCTest, which only resolves when a full Xcode is the
// active toolchain (`xcode-select`). On a CommandLineTools-only / swiftly dev box XCTest is absent,
// so including that target breaks `swift test` entirely. Default to excluding it; opt in with
// OMNIWM_INCLUDE_XCTEST=1 on machines/CI where Xcode is selected. The fork's swift-testing
// OmniWMFeatureTests target runs regardless.
let includeXCTestTarget = ProcessInfo.processInfo.environment["OMNIWM_INCLUDE_XCTEST"] == "1"

let package = Package(
    name: "OmniWM",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "OmniWM",
            targets: ["OmniWMApp"]
        ),
        .executable(
            name: "omniwmctl",
            targets: ["OmniWMCtl"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/mattt/swift-toml.git", from: "2.0.0")
    ],
    targets: [
        .binaryTarget(
            name: "GhosttyKit",
            path: "Frameworks/GhosttyKit.xcframework"
        ),
        .target(
            name: "OmniWMIPC",
            path: "Sources/OmniWMIPC",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "OmniWM",
            dependencies: [
                "GhosttyKit",
                "OmniWMIPC",
                .product(name: "TOML", package: "swift-toml")
            ],
            path: "Sources/OmniWM",
            resources: [
                .process("Resources"),
                .copy("Core/IssueReporter/Prompts")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .interoperabilityMode(.C)
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("QuartzCore"),
                .linkedLibrary("z"),
                .linkedLibrary("c++"),
                .unsafeFlags(["-L\(ghosttyMacOSLibraryDirectory)"]),
                .unsafeFlags(["-F/System/Library/PrivateFrameworks", "-framework", "SkyLight"]),
                .unsafeFlags(["-Xlinker", "-weak_framework", "-Xlinker", "FoundationModels"])
            ]
        ),
        .executableTarget(
            name: "OmniWMApp",
            dependencies: ["OmniWM"],
            path: "Sources/OmniWMApp",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .executableTarget(
            name: "OmniWMCtl",
            dependencies: ["OmniWMIPC"],
            path: "Sources/OmniWMCtl",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        // Fork additions: swift-testing-based tests for ported features (F15 / Zones / Leader).
        // Separate from OmniWMTests (which is XCTest-based and needs full Xcode); these run under
        // the swiftly toolchain alone.
        .testTarget(
            name: "OmniWMFeatureTests",
            dependencies: ["OmniWM"],
            path: "Tests/OmniWMFeatureTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)

if includeXCTestTarget {
    package.targets.append(
        .testTarget(
            name: "OmniWMTests",
            dependencies: ["OmniWM"],
            path: "Tests/OmniWMTests",
            resources: [
                .copy("Fixtures")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    )
}
