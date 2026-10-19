// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "QuitAll",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "quitall", targets: ["QuitAllCLI"]),
        .executable(name: "QuitAllApp", targets: ["QuitAllApp"]),
    ],
    targets: [
        // Motor: qué apps hay abiertas, qué regla les toca, cierre educado y deshacer. Solo frameworks de Apple.
        .target(name: "QuitAllCore"),
        .executableTarget(name: "QuitAllCLI", dependencies: ["QuitAllCore"]),
        .executableTarget(name: "QuitAllApp", dependencies: ["QuitAllCore"]),
    ],
    swiftLanguageVersions: [.v5]
)
