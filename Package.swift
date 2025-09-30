// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NintendoEmulator",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "CoreInterface", targets: ["CoreInterface"]),
        .library(name: "EmulatorKit", targets: ["EmulatorKit"]),
        .library(name: "RenderingEngine", targets: ["RenderingEngine"]),
        .library(name: "AudioEngine", targets: ["AudioEngine"]),
        .library(name: "InputSystem", targets: ["InputSystem"]),
        .library(name: "N64Core", targets: ["N64Core"]),
        // .library(name: "NetworkingKit", targets: ["NetworkingKit"]), // TODO: Implement later
        .library(name: "EmulatorUI", targets: ["EmulatorUI"]),
        .executable(name: "NintendoEmulator", targets: ["NintendoEmulatorApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-atomics", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.5.0"),
    ],
    targets: [
        // Core Interface - Protocol definitions
        .target(
            name: "CoreInterface",
            dependencies: [],
            path: "Sources/CoreInterface"
        ),

        // Placeholder cores (Swift-only, runtime-registered)
        .target(
            name: "SNESCore",
            dependencies: ["CoreInterface"],
            path: "Sources/SNESCore",
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .debug)),
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release))
            ]
        ),
        .target(
            name: "GameCubeCore",
            dependencies: ["CoreInterface"],
            path: "Sources/GameCubeCore",
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .debug)),
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release))
            ]
        ),
        .target(
            name: "WiiCore",
            dependencies: ["CoreInterface"],
            path: "Sources/WiiCore",
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .debug)),
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release))
            ]
        ),

        // N64 adapter using mupen64plus (dynamic loading)
        // C/ObjC bridge for video extension (VidExt)
        .target(
            name: "N64VidExtBridge",
            path: "Sources/N64VidExtBridge",
            publicHeadersPath: ".",
            cSettings: [
                .define("GL_SILENCE_DEPRECATION")
            ],
            linkerSettings: [
                .linkedFramework("OpenGL"),
                .linkedFramework("AppKit")
            ]
        ),

        .target(
            name: "N64MupenAdapter",
            dependencies: [
                "CoreInterface",
                "EmulatorKit",
                "RenderingEngine",
                "N64VidExtBridge",
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/N64MupenAdapter",
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .debug)),
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release))
            ]
        ),

        // Main orchestration framework
        .target(
            name: "EmulatorKit",
            dependencies: [
                "CoreInterface",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "Atomics", package: "swift-atomics"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/EmulatorKit",
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .debug)),
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release))
            ]
        ),

        // Rendering framework
        .target(
            name: "RenderingEngine",
            dependencies: [
                "CoreInterface",
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/RenderingEngine",
            resources: [.copy("Resources/Shaders")],
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .debug)),
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release))
            ]
        ),

        // Audio framework
        .target(
            name: "AudioEngine",
            dependencies: [
                "CoreInterface",
                .product(name: "Atomics", package: "swift-atomics"),
            ],
            path: "Sources/AudioEngine",
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .debug)),
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release))
            ]
        ),

        // Input handling framework
        .target(
            name: "InputSystem",
            dependencies: [
                "CoreInterface",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ],
            path: "Sources/InputSystem",
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .debug)),
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release))
            ]
        ),

        // N64 Core implementation
        .target(
            name: "N64Core",
            dependencies: [
                "CoreInterface",
                "RenderingEngine",
                "EmulatorKit",
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/N64Core",
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .debug)),
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release))
            ]
        ),

        // TODO: Implement networking framework later
        // .target(
        //     name: "NetworkingKit",
        //     dependencies: [
        //         "CoreInterface",
        //         .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
        //     ],
        //     path: "Sources/NetworkingKit"
        // ),

        // UI framework
        .target(
            name: "EmulatorUI",
            dependencies: [
                "EmulatorKit",
                "RenderingEngine",
                "InputSystem",
                "N64MupenAdapter",
            ],
            path: "Sources/EmulatorUI",
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .debug)),
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release))
            ]
        ),

        // Main application
        .executableTarget(
            name: "NintendoEmulatorApp",
            dependencies: [
                "EmulatorUI",
                "EmulatorKit",
                "RenderingEngine",
                "AudioEngine",
                "InputSystem",
                // Link placeholder cores so they are available at runtime
                "SNESCore",
                "GameCubeCore",
                "WiiCore",
                "N64Core",
                "N64MupenAdapter",
                // "NetworkingKit" // TODO: Implement later
            ],
            path: "Sources/NintendoEmulatorApp",
            resources: [.copy("../../Resources")],
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .debug)),
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release))
            ]
        ),

        // Test targets removed - use `make verify` for build verification
    ]
)
