// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "InputPin",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "InputPin", targets: ["InputPin"])],
    targets: [
        .target(name: "InputPinCore"),
        .executableTarget(name: "InputPin", dependencies: ["InputPinCore"]),
        .testTarget(name: "InputPinCoreTests", dependencies: ["InputPinCore"]),
    ]
)
