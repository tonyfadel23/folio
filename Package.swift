// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Folio",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/JohnSundell/Ink.git", from: "0.5.1")
    ],
    targets: [
        .target(
            name: "FolioCore",
            dependencies: ["Ink"]
        ),
        .executableTarget(
            name: "Folio",
            dependencies: ["FolioCore"]
        ),
        // Command Line Tools (no full Xcode) does not ship XCTest, so `swift test`
        // cannot run. Tests are a plain executable runner instead: `swift run FolioTests`.
        .executableTarget(
            name: "FolioTests",
            dependencies: ["FolioCore"]
        )
    ]
)
