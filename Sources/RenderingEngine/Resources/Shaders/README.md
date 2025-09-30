This folder contains Metal shader resources for the RenderingEngine target.

Notes:
- SwiftPM expects resources declared in Package.swift to be located relative to the target path.
- The `Package.swift` declares `resources: [.copy("Resources/Shaders")]` for the `RenderingEngine` target, so this directory must exist at `Sources/RenderingEngine/Resources/Shaders`.
- You can place `.metal` source files here if you plan to compile them into a `.metallib` at build time, or ship precompiled assets.
- The current MetalRenderer also supports compiling inline shader source, so these resources are optional for basic rendering.

