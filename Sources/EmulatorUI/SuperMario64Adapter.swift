import Foundation

/// Game-specific adapter for Super Mario 64
/// Contains known RAM addresses and game-specific state reading
public class SuperMario64Adapter {

    // MARK: - RAM Addresses (US Version 1.0)

    // Player State
    private let playerXAddress: UInt32 = 0x8033B1AC
    private let playerYAddress: UInt32 = 0x8033B1B0
    private let playerZAddress: UInt32 = 0x8033B1B4
    private let playerVelocityXAddress: UInt32 = 0x8033B1B8
    private let playerVelocityYAddress: UInt32 = 0x8033B1BC
    private let playerVelocityZAddress: UInt32 = 0x8033B1C0
    private let playerFacingAngleAddress: UInt32 = 0x8033B19E
    private let playerActionAddress: UInt32 = 0x8033B17C

    // Health & Lives
    private let healthAddress: UInt32 = 0x8033B21E // Health (0-8 segments)
    private let livesAddress: UInt32 = 0x8033B21D // Lives count

    // Stars & Coins
    private let starCountAddress: UInt32 = 0x8033B218 // Total stars
    private let currentLevelStarsAddress: UInt32 = 0x8033BAC6 // Stars in current level
    private let coinCountAddress: UInt32 = 0x8033B21A // Current level coins

    // Level Info
    private let currentLevelAddress: UInt32 = 0x8033BACA // Current level/area
    private let currentAreaAddress: UInt32 = 0x8033BACB // Current sub-area

    // Game State
    private let gameStateAddress: UInt32 = 0x8033B244 // Game state flags
    private let pausedAddress: UInt32 = 0x8032D5D4 // Pause state

    // Camera
    private let cameraXAddress: UInt32 = 0x8033C710
    private let cameraYAddress: UInt32 = 0x8033C714
    private let cameraZAddress: UInt32 = 0x8033C718

    // MARK: - Properties

    private let memoryBridge: N64MemoryBridge

    // MARK: - Initialization

    public init(memoryBridge: N64MemoryBridge) {
        self.memoryBridge = memoryBridge
    }

    // MARK: - State Reading

    public struct GameState {
        // Position
        public var playerX: Float = 0
        public var playerY: Float = 0
        public var playerZ: Float = 0

        // Velocity
        public var velocityX: Float = 0
        public var velocityY: Float = 0
        public var velocityZ: Float = 0
        public var speed: Float = 0

        // Orientation
        public var facingAngle: UInt16 = 0

        // Health & Lives
        public var health: Int = 8
        public var lives: Int = 4
        public var isDead: Bool = false

        // Stars & Coins
        public var totalStars: Int = 0
        public var levelStars: Int = 0
        public var coins: Int = 0

        // Level
        public var level: Int = 0
        public var area: Int = 0

        // Actions
        public var action: PlayerAction = .idle
        public var isGrounded: Bool = true
        public var isUnderwater: Bool = false
        public var isInAir: Bool = false

        // Camera
        public var cameraX: Float = 0
        public var cameraY: Float = 0
        public var cameraZ: Float = 0

        // Game state
        public var isPaused: Bool = false
        public var isGameOver: Bool = false

        public init() {}
    }

    /// Player actions in Super Mario 64
    public enum PlayerAction: UInt32 {
        case idle = 0x0C400201
        case walking = 0x04000440
        case running = 0x04000442
        case jumping = 0x03000880
        case doubleJump = 0x03000881
        case tripleJump = 0x01000883
        case longJump = 0x03000888
        case backflip = 0x01000882
        case sideFlip = 0x01000884
        case falling = 0x0100088C
        case groundPound = 0x008008A7
        case swimming = 0x300022F0
        case dive = 0x018008BE
        case crouching = 0x0C008220
        case crawling = 0x04008441
        case unknown = 0xFFFFFFFF
    }

    /// Read complete game state
    public func readGameState() -> GameState {
        var state = GameState()

        // Position
        state.playerX = memoryBridge.readFloat(playerXAddress)
        state.playerY = memoryBridge.readFloat(playerYAddress)
        state.playerZ = memoryBridge.readFloat(playerZAddress)

        // Velocity
        state.velocityX = memoryBridge.readFloat(playerVelocityXAddress)
        state.velocityY = memoryBridge.readFloat(playerVelocityYAddress)
        state.velocityZ = memoryBridge.readFloat(playerVelocityZAddress)
        state.speed = sqrt(
            state.velocityX * state.velocityX +
            state.velocityZ * state.velocityZ
        )

        // Orientation
        state.facingAngle = memoryBridge.read16(playerFacingAngleAddress)

        // Health & Lives
        state.health = Int(memoryBridge.read8(healthAddress))
        state.lives = Int(memoryBridge.read8(livesAddress))
        state.isDead = state.health == 0

        // Stars & Coins
        state.totalStars = Int(memoryBridge.read8(starCountAddress))
        state.levelStars = Int(memoryBridge.read8(currentLevelStarsAddress))
        state.coins = Int(memoryBridge.read16(coinCountAddress))

        // Level
        state.level = Int(memoryBridge.read8(currentLevelAddress))
        state.area = Int(memoryBridge.read8(currentAreaAddress))

        // Action
        let actionValue = memoryBridge.read32(playerActionAddress)
        state.action = PlayerAction(rawValue: actionValue) ?? .unknown
        state.isInAir = [.jumping, .doubleJump, .tripleJump, .longJump, .falling].contains(state.action)
        state.isGrounded = !state.isInAir && state.action != .swimming
        state.isUnderwater = state.action == .swimming

        // Camera
        state.cameraX = memoryBridge.readFloat(cameraXAddress)
        state.cameraY = memoryBridge.readFloat(cameraYAddress)
        state.cameraZ = memoryBridge.readFloat(cameraZAddress)

        // Game state
        state.isPaused = memoryBridge.read8(pausedAddress) != 0
        state.isGameOver = state.lives == 0

        return state
    }

    // MARK: - Quick Access Methods

    public func getPlayerPosition() -> (x: Float, y: Float, z: Float) {
        return (
            memoryBridge.readFloat(playerXAddress),
            memoryBridge.readFloat(playerYAddress),
            memoryBridge.readFloat(playerZAddress)
        )
    }

    public func getPlayerVelocity() -> (x: Float, y: Float, z: Float) {
        return (
            memoryBridge.readFloat(playerVelocityXAddress),
            memoryBridge.readFloat(playerVelocityYAddress),
            memoryBridge.readFloat(playerVelocityZAddress)
        )
    }

    public func getHealth() -> Int {
        return Int(memoryBridge.read8(healthAddress))
    }

    public func getLives() -> Int {
        return Int(memoryBridge.read8(livesAddress))
    }

    public func getStarCount() -> Int {
        return Int(memoryBridge.read8(starCountAddress))
    }

    public func getCoinCount() -> Int {
        return Int(memoryBridge.read16(coinCountAddress))
    }

    public func getCurrentLevel() -> Int {
        return Int(memoryBridge.read8(currentLevelAddress))
    }

    public func getPlayerAction() -> PlayerAction {
        let actionValue = memoryBridge.read32(playerActionAddress)
        return PlayerAction(rawValue: actionValue) ?? .unknown
    }

    public func isPlayerGrounded() -> Bool {
        let action = getPlayerAction()
        return ![.jumping, .doubleJump, .tripleJump, .falling, .swimming].contains(action)
    }

    public func isPlayerUnderwater() -> Bool {
        return getPlayerAction() == .swimming
    }

    public func isPaused() -> Bool {
        return memoryBridge.read8(pausedAddress) != 0
    }

    public func isGameOver() -> Bool {
        return getLives() == 0
    }

    // MARK: - Level Names

    public func getLevelName(_ levelID: Int) -> String {
        switch levelID {
        case 0: return "Castle Grounds"
        case 1: return "Bob-omb Battlefield"
        case 2: return "Whomp's Fortress"
        case 3: return "Jolly Roger Bay"
        case 4: return "Cool, Cool Mountain"
        case 5: return "Big Boo's Haunt"
        case 6: return "Hazy Maze Cave"
        case 7: return "Lethal Lava Land"
        case 8: return "Shifting Sand Land"
        case 9: return "Dire, Dire Docks"
        case 10: return "Snowman's Land"
        case 11: return "Wet-Dry World"
        case 12: return "Tall, Tall Mountain"
        case 13: return "Tiny-Huge Island"
        case 14: return "Tick Tock Clock"
        case 15: return "Rainbow Ride"
        case 16: return "Castle Inside"
        case 17: return "Bowser 1"
        case 18: return "Vanish Cap"
        case 19: return "Bowser Fire Sea"
        case 20: return "Secret Aquarium"
        case 21: return "Bowser 3"
        case 22: return "Wing Mario"
        case 23: return "Metal Cap"
        case 24: return "Princess's Secret Slide"
        default: return "Unknown Level"
        }
    }

    // MARK: - Action Names

    public func getActionName(_ action: PlayerAction) -> String {
        switch action {
        case .idle: return "Standing"
        case .walking: return "Walking"
        case .running: return "Running"
        case .jumping: return "Jumping"
        case .doubleJump: return "Double Jump"
        case .tripleJump: return "Triple Jump"
        case .longJump: return "Long Jump"
        case .backflip: return "Backflip"
        case .sideFlip: return "Side Flip"
        case .falling: return "Falling"
        case .groundPound: return "Ground Pound"
        case .swimming: return "Swimming"
        case .dive: return "Diving"
        case .crouching: return "Crouching"
        case .crawling: return "Crawling"
        case .unknown: return "Unknown Action"
        }
    }
}