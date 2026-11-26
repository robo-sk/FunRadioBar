// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "FunRadioBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "FunRadioBar", targets: ["FunRadioBar"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1")
    ],
    targets: [
        .executableTarget(
            name: "FunRadioBar",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/FunRadioBar"
        ),
        .testTarget(name: "FunRadioBarTests", dependencies: ["FunRadioBar"])
    ]
)
