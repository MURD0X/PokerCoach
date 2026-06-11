// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PokerEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PokerEngine", targets: ["PokerEngine"]),
    ],
    targets: [
        .target(name: "PokerEngine"),
        .testTarget(name: "PokerEngineTests", dependencies: ["PokerEngine"]),
    ]
)
