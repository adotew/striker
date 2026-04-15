// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Striker",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Striker", targets: ["Striker"]),
    ],
    targets: [
        .target(
            name: "CMarkGFM",
            path: "Sources/CMarkGFM",
            exclude: [
                "src/entities.inc",
                "src/case_fold_switch.inc",
            ],
            sources: ["src", "extensions"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("src"),
                .headerSearchPath("extensions"),
            ]
        ),
        .executableTarget(
            name: "Striker",
            dependencies: ["CMarkGFM"],
            path: "Sources/App"
        )
    ]
)
