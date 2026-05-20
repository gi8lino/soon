// swift-tools-version: 5.10

import PackageDescription

let package = Package(
  name: "Soon",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "Soon", targets: ["Soon"])
  ],
  dependencies: [
    // .package(
    //   url: "https://github.com/gi8lino/easybar.git", exact: "0.0.188"),
    .package(path: "../easybar"),
    .package(url: "https://github.com/LebJe/TOMLKit", from: "0.6.0"),
  ],
  targets: [
    .executableTarget(
      name: "Soon",
      dependencies: [
        .product(name: "EasyBarShared", package: "easybar"),
        .product(name: "EasyBarCalendarConfig", package: "easybar"),
        .product(name: "EasyBarCalendarPresentation", package: "easybar"),
        .product(name: "EasyBarCalendarUI", package: "easybar"),
        .product(name: "TOMLKit", package: "TOMLKit"),
      ],
      path: "Sources/Soon",
      exclude: [
        "App/Info.plist"
      ]
    )
  ]
)
