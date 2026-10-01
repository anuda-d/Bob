// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BobCore",
    platforms: [.macOS(.v14), .iOS(.v26)],
    products: [
        .library(name: "BobCore", targets: ["BobCore"])
    ],
    targets: [
        .target(name: "BobCore"),
        .testTarget(name: "BobCoreTests", dependencies: ["BobCore"]),
        .target(name: "BobMotion", path: "Bob/Camera/Domain"),
        .testTarget(name: "BobMotionTests", dependencies: ["BobMotion"])
    ]
)
