// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Unifer",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Unifer", targets: ["Unifer"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.0")
    ],
    targets: [
        .executableTarget(
            name: "Unifer",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources/Unifer"
        )
    ]
)
