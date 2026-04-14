// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LiquidGlassNote",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "LiquidGlassNote", targets: ["LiquidGlassNote"]),
    ],
    targets: [
        .executableTarget(
            name: "LiquidGlassNote",
            path: "Sources"
        )
    ]
)
