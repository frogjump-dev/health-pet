// swift-tools-version: 5.9
// PetCore: platform-independent pet logic (health models, baselines, pet state, memories).
// No HealthKit / SwiftUI imports here, so it builds and tests on macOS, iOS and Linux.
import PackageDescription

let package = Package(
    name: "PetCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PetCore", targets: ["PetCore"])
    ],
    targets: [
        .target(name: "PetCore"),
        .testTarget(name: "PetCoreTests", dependencies: ["PetCore"])
    ]
)
