// This file ensures core modules are linked into the final app
// so CoreRegistry can discover them via NSClassFromString.
import Foundation
import SNESCore
import GameCubeCore
import WiiCore

// Reference the types so the linker keeps them
private let _linkedCores: [Any] = [
    SNESCore.self,
    GameCubeCore.self,
    WiiCore.self,
]

