import Foundation

/// Game-specific adapter for The Legend of Zelda: Ocarina of Time
/// Contains known RAM addresses and game-specific state reading
public class ZeldaOOTAdapter {

    // MARK: - RAM Addresses (US Version 1.0)

    // Link State
    private let linkXAddress: UInt32 = 0x801DAA54
    private let linkYAddress: UInt32 = 0x801DAA58
    private let linkZAddress: UInt32 = 0x801DAA5C
    private let linkAngleAddress: UInt32 = 0x801DAA66
    private let linkActionAddress: UInt32 = 0x801DAA70

    // Health & Magic
    private let currentHealthAddress: UInt32 = 0x8011A600
    private let maxHealthAddress: UInt32 = 0x8011A602
    private let currentMagicAddress: UInt32 = 0x8011A604
    private let maxMagicAddress: UInt32 = 0x8011A606

    // Rupees & Items
    private let rupeesAddress: UInt32 = 0x8011A604
    private let skulltulaCountAddress: UInt32 = 0x8011A6A0
    private let currentSwordAddress: UInt32 = 0x8011A64C
    private let currentShieldAddress: UInt32 = 0x8011A64D

    // Quest Status
    private let heartPiecesAddress: UInt32 = 0x8011A676
    private let stoneMedallionsAddress: UInt32 = 0x8011A677
    private let gerudoCardAddress: UInt32 = 0x8011A678

    // Scene & Room
    private let currentSceneAddress: UInt32 = 0x801C8545
    private let currentRoomAddress: UInt32 = 0x801C8546

    // Game State
    private let gameStateAddress: UInt32 = 0x801C84F8
    private let pausedAddress: UInt32 = 0x801C6FA8

    // Camera
    private let cameraXAddress: UInt32 = 0x801DB09C
    private let cameraYAddress: UInt32 = 0x801DB0A0
    private let cameraZAddress: UInt32 = 0x801DB0A4

    // MARK: - Properties

    private let memoryBridge: N64MemoryBridge

    // MARK: - Initialization

    public init(memoryBridge: N64MemoryBridge) {
        self.memoryBridge = memoryBridge
    }

    // MARK: - State Reading

    public struct GameState {
        // Position
        public var linkX: Float = 0
        public var linkY: Float = 0
        public var linkZ: Float = 0

        // Orientation
        public var facingAngle: UInt16 = 0

        // Health & Magic
        public var currentHealth: Int = 48 // 3 hearts * 16
        public var maxHealth: Int = 48
        public var currentMagic: Int = 0
        public var maxMagic: Int = 0
        public var hearts: Float = 3.0
        public var isDead: Bool = false

        // Currency & Items
        public var rupees: Int = 0
        public var skulltulas: Int = 0
        public var currentSword: Sword = .none
        public var currentShield: Shield = .none

        // Quest
        public var heartPieces: Int = 0
        public var stoneMedallions: Int = 0
        public var hasGerudoCard: Bool = false

        // Location
        public var scene: Int = 0
        public var room: Int = 0
        public var sceneName: String = "Unknown"

        // Actions
        public var action: LinkAction = .idle
        public var isInCombat: Bool = false
        public var isSwimming: Bool = false
        public var isClimbing: Bool = false

        // Camera
        public var cameraX: Float = 0
        public var cameraY: Float = 0
        public var cameraZ: Float = 0

        // Game state
        public var isPaused: Bool = false
        public var isGameOver: Bool = false

        public init() {}
    }

    /// Link's equipped sword
    public enum Sword: UInt8 {
        case none = 0
        case kokiriSword = 1
        case masterSword = 2
        case giantKnife = 3
        case biggoronSword = 4
    }

    /// Link's equipped shield
    public enum Shield: UInt8 {
        case none = 0
        case dekuShield = 1
        case hylianShield = 2
        case mirrorShield = 3
    }

    /// Link's actions
    public enum LinkAction: UInt32 {
        case idle = 0x00
        case walking = 0x01
        case running = 0x02
        case attacking = 0x03
        case defending = 0x04
        case rolling = 0x05
        case swimming = 0x06
        case climbing = 0x07
        case jumping = 0x08
        case falling = 0x09
        case damaged = 0x0A
        case unknown = 0xFF
    }

    /// Read complete game state
    public func readGameState() -> GameState {
        var state = GameState()

        // Position
        state.linkX = memoryBridge.readFloat(linkXAddress)
        state.linkY = memoryBridge.readFloat(linkYAddress)
        state.linkZ = memoryBridge.readFloat(linkZAddress)

        // Orientation
        state.facingAngle = memoryBridge.read16(linkAngleAddress)

        // Health & Magic
        state.currentHealth = Int(memoryBridge.read16(currentHealthAddress))
        state.maxHealth = Int(memoryBridge.read16(maxHealthAddress))
        state.currentMagic = Int(memoryBridge.read8(currentMagicAddress))
        state.maxMagic = Int(memoryBridge.read8(maxMagicAddress))
        state.hearts = Float(state.currentHealth) / 16.0 // 16 units = 1 heart
        state.isDead = state.currentHealth == 0

        // Currency & Items
        state.rupees = Int(memoryBridge.read16(rupeesAddress))
        state.skulltulas = Int(memoryBridge.read16(skulltulaCountAddress))
        state.currentSword = Sword(rawValue: memoryBridge.read8(currentSwordAddress)) ?? .none
        state.currentShield = Shield(rawValue: memoryBridge.read8(currentShieldAddress)) ?? .none

        // Quest
        state.heartPieces = Int(memoryBridge.read8(heartPiecesAddress))
        state.stoneMedallions = Int(memoryBridge.read8(stoneMedallionsAddress))
        state.hasGerudoCard = memoryBridge.read8(gerudoCardAddress) != 0

        // Location
        state.scene = Int(memoryBridge.read8(currentSceneAddress))
        state.room = Int(memoryBridge.read8(currentRoomAddress))
        state.sceneName = getSceneName(state.scene)

        // Action
        let actionValue = memoryBridge.read32(linkActionAddress)
        state.action = LinkAction(rawValue: actionValue & 0xFF) ?? .unknown
        state.isSwimming = state.action == .swimming
        state.isClimbing = state.action == .climbing
        state.isInCombat = [.attacking, .defending].contains(state.action)

        // Camera
        state.cameraX = memoryBridge.readFloat(cameraXAddress)
        state.cameraY = memoryBridge.readFloat(cameraYAddress)
        state.cameraZ = memoryBridge.readFloat(cameraZAddress)

        // Game state
        state.isPaused = memoryBridge.read8(pausedAddress) != 0
        state.isGameOver = state.isDead

        return state
    }

    // MARK: - Quick Access Methods

    public func getLinkPosition() -> (x: Float, y: Float, z: Float) {
        return (
            memoryBridge.readFloat(linkXAddress),
            memoryBridge.readFloat(linkYAddress),
            memoryBridge.readFloat(linkZAddress)
        )
    }

    public func getCurrentHealth() -> Int {
        return Int(memoryBridge.read16(currentHealthAddress))
    }

    public func getMaxHealth() -> Int {
        return Int(memoryBridge.read16(maxHealthAddress))
    }

    public func getHearts() -> Float {
        return Float(getCurrentHealth()) / 16.0
    }

    public func getRupeeCount() -> Int {
        return Int(memoryBridge.read16(rupeesAddress))
    }

    public func getSkulltulaCount() -> Int {
        return Int(memoryBridge.read16(skulltulaCountAddress))
    }

    public func getCurrentScene() -> Int {
        return Int(memoryBridge.read8(currentSceneAddress))
    }

    public func getLinkAction() -> LinkAction {
        let actionValue = memoryBridge.read32(linkActionAddress)
        return LinkAction(rawValue: actionValue & 0xFF) ?? .unknown
    }

    public func isPaused() -> Bool {
        return memoryBridge.read8(pausedAddress) != 0
    }

    public func isGameOver() -> Bool {
        return getCurrentHealth() == 0
    }

    // MARK: - Scene Names

    public func getSceneName(_ sceneID: Int) -> String {
        switch sceneID {
        case 0x00: return "Hyrule Field"
        case 0x01: return "Kakariko Village"
        case 0x02: return "Graveyard"
        case 0x03: return "Zora's River"
        case 0x04: return "Kokiri Forest"
        case 0x05: return "Sacred Forest Meadow"
        case 0x06: return "Lake Hylia"
        case 0x07: return "Zora's Domain"
        case 0x08: return "Zora's Fountain"
        case 0x09: return "Gerudo Valley"
        case 0x0A: return "Lost Woods"
        case 0x0B: return "Desert Colossus"
        case 0x0C: return "Gerudo's Fortress"
        case 0x0D: return "Haunted Wasteland"
        case 0x0E: return "Hyrule Castle"
        case 0x0F: return "Death Mountain Trail"
        case 0x10: return "Death Mountain Crater"
        case 0x11: return "Goron City"
        case 0x12: return "Lon Lon Ranch"
        case 0x13: return "Temple of Time"
        case 0x14: return "Market"
        case 0x15: return "Back Alley"
        case 0x16: return "Castle Courtyard"
        case 0x17: return "Zelda's Courtyard"
        case 0x18: return "Deku Tree"
        case 0x19: return "Dodongo's Cavern"
        case 0x1A: return "Jabu-Jabu's Belly"
        case 0x1B: return "Forest Temple"
        case 0x1C: return "Fire Temple"
        case 0x1D: return "Water Temple"
        case 0x1E: return "Spirit Temple"
        case 0x1F: return "Shadow Temple"
        case 0x20: return "Bottom of the Well"
        case 0x21: return "Ice Cavern"
        case 0x22: return "Ganon's Tower"
        case 0x23: return "Gerudo Training Ground"
        case 0x24: return "Thieves' Hideout"
        case 0x25: return "Inside Ganon's Castle"
        default: return "Unknown Scene"
        }
    }

    // MARK: - Sword Names

    public func getSwordName(_ sword: Sword) -> String {
        switch sword {
        case .none: return "No Sword"
        case .kokiriSword: return "Kokiri Sword"
        case .masterSword: return "Master Sword"
        case .giantKnife: return "Giant's Knife"
        case .biggoronSword: return "Biggoron Sword"
        }
    }

    // MARK: - Shield Names

    public func getShieldName(_ shield: Shield) -> String {
        switch shield {
        case .none: return "No Shield"
        case .dekuShield: return "Deku Shield"
        case .hylianShield: return "Hylian Shield"
        case .mirrorShield: return "Mirror Shield"
        }
    }

    // MARK: - Action Names

    public func getActionName(_ action: LinkAction) -> String {
        switch action {
        case .idle: return "Standing"
        case .walking: return "Walking"
        case .running: return "Running"
        case .attacking: return "Attacking"
        case .defending: return "Defending"
        case .rolling: return "Rolling"
        case .swimming: return "Swimming"
        case .climbing: return "Climbing"
        case .jumping: return "Jumping"
        case .falling: return "Falling"
        case .damaged: return "Taking Damage"
        case .unknown: return "Unknown Action"
        }
    }
}