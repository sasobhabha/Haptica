// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Haptica",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Haptica",
            targets: ["Haptica"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Haptica",
            path: "Sources"
        )
    ]
)
