// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Textream",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Textream", targets: ["Textream"])
    ],
    targets: [
        .executableTarget(name: "Textream")
    ]
)
