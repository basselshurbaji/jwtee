// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "jwtee",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "JWTCore", targets: ["JWTCore"]),
        .executable(name: "jwtee", targets: ["JWTeeApp"]),
    ],
    targets: [
        .target(
            name: "JWTCore"
        ),
        .executableTarget(
            name: "JWTeeApp",
            dependencies: ["JWTCore"]
        ),
        // Run with `swift test` (uses Apple's swift-testing framework).
        .testTarget(
            name: "JWTCoreTests",
            dependencies: ["JWTCore"]
        ),
    ]
)
