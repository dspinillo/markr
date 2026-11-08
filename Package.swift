// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Markr",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Markr", targets: ["Markr"])
    ],
    targets: [
        .executableTarget(
            name: "Markr",
            path: "Sources/Markr"
        )
    ]
)
