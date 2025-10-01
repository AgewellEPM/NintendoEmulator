import Foundation

/// Reads game state from emulator RAM
/// Provides access to player position, health, score, etc.
public class MemoryReader {

    // MARK: - Types

    /// Game state snapshot
    public struct GameState {
        public var playerX: Float = 0
        public var playerY: Float = 0
        public var playerZ: Float = 0
        public var health: Int = 100
        public var score: Int = 0
        public var lives: Int = 3
        public var coins: Int = 0
        public var stars: Int = 0
        public var isGameOver: Bool = false
        public var isPaused: Bool = false

        public init() {}
    }

    /// Game-specific memory addresses
    public struct GameAddresses {
        var playerX: UInt32
        var playerY: UInt32
        var playerZ: UInt32
        var health: UInt32
        var score: UInt32
        var lives: UInt32
        var coins: UInt32
        var stars: UInt32
        var gameState: UInt32

        public init(playerX: UInt32 = 0, playerY: UInt32 = 0, playerZ: UInt32 = 0, health: UInt32 = 0, score: UInt32 = 0, lives: UInt32 = 0, coins: UInt32 = 0, stars: UInt32 = 0, gameState: UInt32 = 0) {
            self.playerX = playerX
            self.playerY = playerY
            self.playerZ = playerZ
            self.health = health
            self.score = score
            self.lives = lives
            self.coins = coins
            self.stars = stars
            self.gameState = gameState
        }
    }

    // MARK: - Properties

    private var currentGame: String?
    private var addresses: GameAddresses = .init()

    // Memory bridge and game adapters
    private var memoryBridge: N64MemoryBridge?
    private var sm64Adapter: SuperMario64Adapter?
    private var zeldaAdapter: ZeldaOOTAdapter?

    /// Expose MachVM for direct memory operations
    public func getMachVM() -> MachVMMemoryAccess? {
        return memoryBridge?.getMachVM()
    }

    // Game-specific address databases
    private let knownGames: [String: GameAddresses] = [
        "Super Mario 64": GameAddresses(
            playerX: 0x8033B1AC,
            playerY: 0x8033B1B0,
            playerZ: 0x8033B1B4,
            health: 0x8033B218,
            score: 0x8033B218,
            lives: 0x8033B21C,
            coins: 0x8033B21E,
            stars: 0x8033B218,
            gameState: 0x8033B244
        ),
        "Legend of Zelda": GameAddresses(
            playerX: 0x801DAA54,
            playerY: 0x801DAA58,
            playerZ: 0x801DAA5C,
            health: 0x8011A600,
            score: 0x8011A604,
            lives: 0x8011A608,
            coins: 0x8011A60C,
            stars: 0,
            gameState: 0x8011A610
        )
    ]

    // MARK: - Initialization

    public init() {}

    // MARK: - Setup

    /// Configure memory reader for a specific game
    public func configureForGame(_ gameName: String) {
        currentGame = gameName

        // Load known addresses if available
        if let gameAddresses = knownGames[gameName] {
            addresses = gameAddresses
            print("💾 [MemoryReader] Loaded addresses for \(gameName)")
        } else {
            print("⚠️ [MemoryReader] No known addresses for \(gameName) - using defaults")
        }
    }

    /// Connect to emulator memory via PID
    public func connectToEmulator(pid: pid_t) -> Bool {
        let bridge = N64MemoryBridge()
        guard bridge.connect(emulatorPID: pid) else {
            print("⚠️ [MemoryReader] Failed to connect to emulator PID: \(pid)")
            return false
        }

        memoryBridge = bridge

        // Initialize game-specific adapters
        if let gameName = currentGame {
            if gameName.contains("Mario") || gameName.contains("SM64") {
                sm64Adapter = SuperMario64Adapter(memoryBridge: bridge)
                print("💾 [MemoryReader] Initialized Super Mario 64 adapter")
            } else if gameName.contains("Zelda") || gameName.contains("OOT") {
                zeldaAdapter = ZeldaOOTAdapter(memoryBridge: bridge)
                print("💾 [MemoryReader] Initialized Zelda OOT adapter")
            }
        }

        print("💾 [MemoryReader] Connected to emulator")
        return true
    }

    /// Disconnect from emulator
    public func disconnect() {
        memoryBridge?.disconnect()
        memoryBridge = nil
        sm64Adapter = nil
        zeldaAdapter = nil
        print("💾 [MemoryReader] Disconnected")
    }

    // MARK: - Memory Reading (Stub - needs mupen64plus integration)

    /// Read 8-bit value from memory address
    public func read8(_ address: UInt32) -> UInt8 {
        return memoryBridge?.read8(address) ?? 0
    }

    /// Read 16-bit value from memory address
    public func read16(_ address: UInt32) -> UInt16 {
        return memoryBridge?.read16(address) ?? 0
    }

    /// Read 32-bit value from memory address
    public func read32(_ address: UInt32) -> UInt32 {
        return memoryBridge?.read32(address) ?? 0
    }

    /// Read float from memory address
    public func readFloat(_ address: UInt32) -> Float {
        return memoryBridge?.readFloat(address) ?? 0.0
    }

    // MARK: - High-Level Game State Reading

    /// Get complete game state snapshot
    public func getGameState() -> GameState {
        var state = GameState()

        if addresses.playerX != 0 {
            state.playerX = readFloat(addresses.playerX)
        }
        if addresses.playerY != 0 {
            state.playerY = readFloat(addresses.playerY)
        }
        if addresses.playerZ != 0 {
            state.playerZ = readFloat(addresses.playerZ)
        }
        if addresses.health != 0 {
            state.health = Int(read16(addresses.health))
        }
        if addresses.score != 0 {
            state.score = Int(read32(addresses.score))
        }
        if addresses.lives != 0 {
            state.lives = Int(read8(addresses.lives))
        }
        if addresses.coins != 0 {
            state.coins = Int(read16(addresses.coins))
        }
        if addresses.stars != 0 {
            state.stars = Int(read8(addresses.stars))
        }

        // Detect game over
        state.isGameOver = state.lives == 0 || state.health == 0

        return state
    }

    /// Get player position
    public func getPlayerPosition() -> (x: Float, y: Float, z: Float) {
        return (
            readFloat(addresses.playerX),
            readFloat(addresses.playerY),
            readFloat(addresses.playerZ)
        )
    }

    /// Get player health (0-100)
    public func getPlayerHealth() -> Int {
        if addresses.health == 0 { return 100 }
        return Int(read16(addresses.health))
    }

    /// Get player score
    public func getPlayerScore() -> Int {
        if addresses.score == 0 { return 0 }
        return Int(read32(addresses.score))
    }

    /// Get number of lives
    public func getLives() -> Int {
        if addresses.lives == 0 { return 3 }
        return Int(read8(addresses.lives))
    }

    /// Get coin count
    public func getCoins() -> Int {
        if addresses.coins == 0 { return 0 }
        return Int(read16(addresses.coins))
    }

    /// Get star count
    public func getStars() -> Int {
        if addresses.stars == 0 { return 0 }
        return Int(read8(addresses.stars))
    }

    /// Check if game is over
    public func isGameOver() -> Bool {
        let lives = getLives()
        let health = getPlayerHealth()
        return lives == 0 || health == 0
    }

    /// Check if game is paused
    public func isGamePaused() -> Bool {
        // TODO: Read pause flag from memory
        return false
    }

    // MARK: - Custom Address Reading

    /// Read from custom address (for advanced users)
    public func readCustom8(_ address: UInt32) -> UInt8 {
        return read8(address)
    }

    public func readCustom16(_ address: UInt32) -> UInt16 {
        return read16(address)
    }

    public func readCustom32(_ address: UInt32) -> UInt32 {
        return read32(address)
    }

    public func readCustomFloat(_ address: UInt32) -> Float {
        return readFloat(address)
    }

    // MARK: - Address Management

    /// Set custom address for a game variable
    public func setAddress(playerX: UInt32) {
        addresses.playerX = playerX
    }

    public func setAddress(playerY: UInt32) {
        addresses.playerY = playerY
    }

    public func setAddress(playerZ: UInt32) {
        addresses.playerZ = playerZ
    }

    public func setAddress(health: UInt32) {
        addresses.health = health
    }

    public func setAddress(score: UInt32) {
        addresses.score = score
    }

    public func setAddress(lives: UInt32) {
        addresses.lives = lives
    }

    public func setAddress(coins: UInt32) {
        addresses.coins = coins
    }

    public func setAddress(stars: UInt32) {
        addresses.stars = stars
    }

    /// Export current address configuration
    public func exportAddresses() -> GameAddresses {
        return addresses
    }

    /// Import address configuration
    public func importAddresses(_ addresses: GameAddresses) {
        self.addresses = addresses
        print("💾 [MemoryReader] Imported custom addresses")
    }
}

// MARK: - Future Integration Notes

/*
 To fully implement memory reading, we need to:

 1. Add memory API to N64MupenAdapter.swift:
    ```swift
    public func readMemory(address: UInt32, size: Int) -> Data? {
        // Call mupen64plus memory API:
        // DebugMemGetPointer(address)
        // or via mupen64plus CLI with memory dump
    }
    ```

 2. Option A: Use mupen64plus core API (requires loading libmupen64plus.dylib)
    - Call DebugMemGetPointer(M64P_DBG_PTR_RDRAM)
    - Direct memory access to emulator RAM

 3. Option B: Use memory dumps (simpler but slower)
    - Periodically dump memory to file
    - Read from file in Swift
    - ~1-5 FPS update rate (vs 60 FPS with direct access)

 4. Option C: Use process memory reading (macOS specific)
    - Read from mupen64plus process memory via task_for_pid
    - Requires elevated permissions
    - Works with CLI version

 Recommended: Start with Option B (dumps) for proof of concept,
              then upgrade to Option A (direct API) for production
 */