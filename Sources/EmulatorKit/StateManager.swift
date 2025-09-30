import Foundation
import CoreInterface
import os.log

/// Manages save states and game saves
public actor StateManager {

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.emulator", category: "StateManager")

    private var statesDirectory: URL
    private var savesDirectory: URL
    private var currentGameID: String?

    // Cache for quick states
    private var quickStates: [Int: Data] = [:]
    private let maxQuickStates = 10

    // MARK: - Initialization

    public init() {
        // Setup directories
        let documentsPath = fileManager.urls(for: .documentDirectory,
                                            in: .userDomainMask).first!
        self.statesDirectory = documentsPath.appendingPathComponent("SaveStates")
        self.savesDirectory = documentsPath.appendingPathComponent("GameSaves")

        Task {
            await createDirectories()
        }
    }

    // MARK: - Public Methods

    /// Set current game identifier
    public func setCurrentGame(_ gameID: String) {
        self.currentGameID = gameID
        logger.info("Current game set to: \(gameID)")
    }

    /// Save state to file
    public func saveState(_ data: Data, slot: Int? = nil) async throws -> URL {
        guard let gameID = currentGameID else {
            throw EmulatorError.saveStateFailed("No game loaded")
        }

        let fileName: String
        if let slot = slot {
            fileName = "\(gameID)_slot_\(slot).state"
        } else {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            fileName = "\(gameID)_\(timestamp).state"
        }

        let url = statesDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: url)
            logger.info("State saved to: \(fileName)")
            return url
        } catch {
            logger.error("Failed to save state: \(error.localizedDescription)")
            throw EmulatorError.saveStateFailed(error.localizedDescription)
        }
    }

    /// Load state from file
    public func loadState(from url: URL) async throws -> Data {
        do {
            let data = try Data(contentsOf: url)
            logger.info("State loaded from: \(url.lastPathComponent)")
            return data
        } catch {
            logger.error("Failed to load state: \(error.localizedDescription)")
            throw EmulatorError.loadStateFailed(error.localizedDescription)
        }
    }

    /// Quick save to memory slot
    public func quickSave(_ data: Data, slot: Int) async {
        guard slot >= 0 && slot < maxQuickStates else {
            logger.warning("Invalid quick save slot: \(slot)")
            return
        }

        quickStates[slot] = data
        logger.info("Quick saved to slot \(slot)")

        // Also save to disk for persistence
        _ = try? await saveState(data, slot: slot)
    }

    /// Quick load from memory slot
    public func quickLoad(slot: Int) async throws -> Data {
        guard slot >= 0 && slot < maxQuickStates else {
            throw EmulatorError.loadStateFailed("Invalid slot: \(slot)")
        }

        // Try memory first
        if let data = quickStates[slot] {
            logger.info("Quick loaded from memory slot \(slot)")
            return data
        }

        // Try disk
        guard let gameID = currentGameID else {
            throw EmulatorError.loadStateFailed("No game loaded")
        }

        let fileName = "\(gameID)_slot_\(slot).state"
        let url = statesDirectory.appendingPathComponent(fileName)

        guard fileManager.fileExists(atPath: url.path) else {
            throw EmulatorError.loadStateFailed("No state in slot \(slot)")
        }

        let data = try await loadState(from: url)
        quickStates[slot] = data // Cache it
        return data
    }

    /// List available save states
    public func listSaveStates(for gameID: String? = nil) async -> [SaveStateInfo] {
        let id = gameID ?? currentGameID ?? ""
        guard !id.isEmpty else { return [] }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: statesDirectory,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: .skipsHiddenFiles
            )

            let states = contents.compactMap { url -> SaveStateInfo? in
                guard url.lastPathComponent.hasPrefix(id) &&
                      url.pathExtension == "state" else { return nil }

                let attributes = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])

                return SaveStateInfo(
                    url: url,
                    gameID: id,
                    slot: extractSlot(from: url.lastPathComponent),
                    date: attributes?.creationDate ?? Date(),
                    size: attributes?.fileSize ?? 0
                )
            }

            return states.sorted { $0.date > $1.date }
        } catch {
            logger.error("Failed to list save states: \(error.localizedDescription)")
            return []
        }
    }

    /// Delete save state
    public func deleteSaveState(at url: URL) async throws {
        try fileManager.removeItem(at: url)
        logger.info("Deleted save state: \(url.lastPathComponent)")

        // Clear from cache if it's a quick state
        if let slot = extractSlot(from: url.lastPathComponent) {
            quickStates[slot] = nil
        }
    }

    /// Export save state
    public func exportSaveState(from url: URL, to destination: URL) async throws {
        try fileManager.copyItem(at: url, to: destination)
        logger.info("Exported save state to: \(destination.path)")
    }

    /// Import save state
    public func importSaveState(from url: URL) async throws -> URL {
        let fileName = url.lastPathComponent
        let destination = statesDirectory.appendingPathComponent(fileName)

        // Check if already exists
        if fileManager.fileExists(atPath: destination.path) {
            let newName = generateUniqueFileName(for: fileName)
            let newDestination = statesDirectory.appendingPathComponent(newName)
            try fileManager.copyItem(at: url, to: newDestination)
            logger.info("Imported save state as: \(newName)")
            return newDestination
        }

        try fileManager.copyItem(at: url, to: destination)
        logger.info("Imported save state: \(fileName)")
        return destination
    }

    // MARK: - Game Saves (Battery/SRAM)

    /// Save game data
    public func saveGameData(_ data: Data, type: SaveType) async throws {
        guard let gameID = currentGameID else {
            throw EmulatorError.saveStateFailed("No game loaded")
        }

        let fileName = "\(gameID).\(type.fileExtension)"
        let url = savesDirectory.appendingPathComponent(fileName)

        try data.write(to: url)
        logger.info("Game data saved: \(fileName)")
    }

    /// Load game data
    public func loadGameData(type: SaveType) async throws -> Data? {
        guard let gameID = currentGameID else {
            throw EmulatorError.loadStateFailed("No game loaded")
        }

        let fileName = "\(gameID).\(type.fileExtension)"
        let url = savesDirectory.appendingPathComponent(fileName)

        guard fileManager.fileExists(atPath: url.path) else {
            return nil // No save exists yet
        }

        let data = try Data(contentsOf: url)
        logger.info("Game data loaded: \(fileName)")
        return data
    }

    // MARK: - Private Methods

    private func createDirectories() {
        _ = try? fileManager.createDirectory(
            at: statesDirectory,
            withIntermediateDirectories: true
        )
        _ = try? fileManager.createDirectory(
            at: savesDirectory,
            withIntermediateDirectories: true
        )
    }

    private func extractSlot(from fileName: String) -> Int? {
        let pattern = "slot_(\\d+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(location: 0, length: fileName.count)
        guard let match = regex.firstMatch(in: fileName, range: range),
              let slotRange = Range(match.range(at: 1), in: fileName) else { return nil }

        return Int(fileName[slotRange])
    }

    private func generateUniqueFileName(for fileName: String) -> String {
        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension

        var counter = 1
        var newName = "\(name)_\(counter).\(ext)"

        while fileManager.fileExists(atPath: statesDirectory.appendingPathComponent(newName).path) {
            counter += 1
            newName = "\(name)_\(counter).\(ext)"
        }

        return newName
    }
}

// MARK: - Supporting Types

public struct SaveStateInfo {
    public let url: URL
    public let gameID: String
    public let slot: Int?
    public let date: Date
    public let size: Int
}

public enum SaveType {
    case sram
    case eeprom
    case flash
    case memoryCard

    var fileExtension: String {
        switch self {
        case .sram: return "srm"
        case .eeprom: return "eep"
        case .flash: return "fla"
        case .memoryCard: return "mcd"
        }
    }
}
