// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Striker",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Striker", targets: ["Striker"]),
    ],
    targets: [
        .executableTarget(
            name: "Striker",
            path: "Sources/App"
        )
    ]
)
