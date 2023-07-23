// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AnachronisticTechAPI",
    platforms: [
       .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "AnachronisticTechAPI",
            targets: ["AnachronisticTechAPI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/AnachronisticTech/WebServiceBuilder", from: "1.0.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/johnsundell/Ink.git", from: "0.5.0"),
        .package(url: "https://github.com/JohnSundell/Files", from: "4.0.0"),
        .package(name: "HTMLEntities", url: "https://github.com/IBM-Swift/swift-html-entities.git", from: "3.0.14")
    ],
    targets: [
        .target(
            name: "AnachronisticTechAPI",
            dependencies: [
                .product(name: "WebServiceBuilder", package: "WebServiceBuilder"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "Files", package: "Files"),
                .product(name: "Ink", package: "Ink"),
                .product(name: "HTMLEntities", package: "HTMLEntities")
            ],
            resources: [
                .copy("Resources"),
                .copy("Public")
            ]
        ),
    ]
)
