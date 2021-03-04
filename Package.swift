// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "JustLogDataDogDestination",
    platforms: [.iOS("10.0.0"), .tvOS("10.0.0")],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "JustLogDataDogDestination",
            targets: ["JustLogDataDogDestination"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
         .package(url: "https://github.com/justeat/JustLog.git", from: "3.2.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "JustLogDataDogDestination",
            dependencies: []),
        .testTarget(
            name: "JustLogDataDogDestinationTests",
            dependencies: ["JustLogDataDogDestination"]),
    ]
)
