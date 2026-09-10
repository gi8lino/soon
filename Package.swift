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
    //.package(path: "../easybar-kit"),
    .package(
      url: "https://github.com/easybar-app/easybar-kit",
      from: "0.6.0",
    ),
    .package(
      url: "https://github.com/gi8lino/SwiftTOMLEdit.git",
      from: "0.0.5",
    ),
  ],
  targets: [
    .executableTarget(
      name: "SoonGenerateBuildInfo",
      path: "Sources/SoonGenerateBuildInfo"
    ),
    .executableTarget(
      name: "Soon",
      dependencies: [
        .product(name: "EasyBarShared", package: "easybar-kit"),
        .product(name: "EasyBarCalendarConfig", package: "easybar-kit"),
        .product(name: "EasyBarCalendarCore", package: "easybar-kit"),
        .product(name: "EasyBarCalendarPresentation", package: "easybar-kit"),
        .product(name: "EasyBarCalendarUI", package: "easybar-kit"),
        .product(name: "SwiftTOMLEdit", package: "swifttomledit"),
      ],
      path: "Sources/Soon",
      plugins: [
        .plugin(name: "SoonBuildInfoPlugin")
      ]
    ),
    .testTarget(
      name: "SoonTests",
      dependencies: [
        "Soon",
        .product(name: "SwiftTOMLEdit", package: "swifttomledit"),
      ],
      path: "Tests/SoonTests",
    ),
    .plugin(
      name: "SoonBuildInfoPlugin",
      capability: .buildTool(),
      dependencies: [
        "SoonGenerateBuildInfo"
      ]
    ),
  ]
)
