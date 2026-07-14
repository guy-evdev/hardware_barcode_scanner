// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "hardware_barcode_scanner",
  platforms: [
    .iOS("12.0")
  ],
  products: [
    .library(name: "hardware-barcode-scanner", targets: ["hardware_barcode_scanner"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework")
  ],
  targets: [
    .target(
      name: "hardware_barcode_scanner",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework")
      ],
      resources: [
        .process("PrivacyInfo.xcprivacy")
      ]
    )
  ]
)
