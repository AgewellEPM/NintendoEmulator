import Foundation
import CoreInterface
import Combine

/// Memory viewer and hex editor for debugging
public final class MemoryViewer: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var currentAddress: UInt32 = 0
    @Published public private(set) var memoryData: [UInt8] = []
    @Published public private(set) var memoryRegions: [MemoryRegion] = []
    @Published public private(set) var searchResults: [SearchResult] = []
    @Published public private(set) var bookmarks: [MemoryBookmark] = []
    @Published public var viewMode: ViewMode = .hex
    @Published public var bytesPerLine: Int = 16
    @Published public var dataSize: DataSize = .byte

    // MARK: - Types

    public enum ViewMode {
        case hex
        case ascii
        case disassembly
        case mixed
    }

    public enum DataSize {
        case byte
        case word
        case dword
        case qword

        public var byteCount: Int {
            switch self {
            case .byte: return 1
            case .word: return 2
            case .dword: return 4
            case .qword: return 8
            }
        }
    }

    public struct MemoryRegion {
        public let name: String
        public let startAddress: UInt32
        public let endAddress: UInt32
        public let permissions: Permissions
        public let description: String

        public struct Permissions: OptionSet {
            public let rawValue: Int

            public init(rawValue: Int) {
                self.rawValue = rawValue
            }

            public static let read = Permissions(rawValue: 1 << 0)
            public static let write = Permissions(rawValue: 1 << 1)
            public static let execute = Permissions(rawValue: 1 << 2)
        }

        public var size: UInt32 {
            endAddress - startAddress + 1
        }
    }

    public struct SearchResult {
        public let address: UInt32
        public let data: [UInt8]
        public let context: String
    }

    public struct MemoryBookmark {
        public let id = UUID()
        public let address: UInt32
        public let name: String
        public let description: String?
        public let color: BookmarkColor

        public enum BookmarkColor: String, CaseIterable {
            case red = "red"
            case blue = "blue"
            case green = "green"
            case yellow = "yellow"
            case purple = "purple"
            case orange = "orange"
        }
    }

    // MARK: - Private Properties

    private var emulatorCore: EmulatorCoreProtocol?
    private let chunkSize = 4096
    private var loadedChunks: [UInt32: [UInt8]] = [:]

    // MARK: - Initialization

    public init() {
        setupMemoryRegions()
    }

    // MARK: - Public Methods

    /// Connect to emulator core
    public func connect(to core: EmulatorCoreProtocol) {
        emulatorCore = core
        refreshMemoryRegions()
    }

    /// Disconnect from emulator core
    public func disconnect() {
        emulatorCore = nil
        loadedChunks.removeAll()
        memoryData.removeAll()
    }

    /// Navigate to specific address
    public func goToAddress(_ address: UInt32) {
        currentAddress = address
        loadMemoryAtAddress(address)
    }

    /// Read memory at current address
    public func refreshMemory() {
        loadMemoryAtAddress(currentAddress)
    }

    /// Write data to memory
    public func writeMemory(at address: UInt32, data: [UInt8]) -> Bool {
        guard emulatorCore != nil else { return false }

        // This would be implemented by the core
        // For now, simulate the write
        let chunkAddress = address & ~UInt32(chunkSize - 1)
        if var chunk = loadedChunks[chunkAddress] {
            let offset = Int(address - chunkAddress)
            for (i, byte) in data.enumerated() {
                if offset + i < chunk.count {
                    chunk[offset + i] = byte
                }
            }
            loadedChunks[chunkAddress] = chunk
        }

        // Refresh display if writing to current view
        if address >= currentAddress && address < currentAddress + UInt32(memoryData.count) {
            refreshMemory()
        }

        return true
    }

    /// Search for byte pattern
    public func searchPattern(_ pattern: [UInt8], in region: MemoryRegion? = nil) {
        searchResults.removeAll()

        let searchRegions = region.map { [$0] } ?? memoryRegions.filter { $0.permissions.contains(.read) }

        for region in searchRegions {
            let results = performPatternSearch(pattern, in: region)
            searchResults.append(contentsOf: results)
        }
    }

    /// Search for string
    public func searchString(_ string: String, encoding: String.Encoding = .utf8) {
        guard let data = string.data(using: encoding) else { return }
        searchPattern(Array(data))
    }

    /// Search for value
    public func searchValue<T: FixedWidthInteger>(_ value: T) {
        let data = withUnsafeBytes(of: value.littleEndian) { Array($0) }
        searchPattern(data)
    }

    /// Add bookmark
    public func addBookmark(at address: UInt32, name: String, description: String? = nil, color: MemoryBookmark.BookmarkColor = .blue) {
        let bookmark = MemoryBookmark(
            address: address,
            name: name,
            description: description,
            color: color
        )
        bookmarks.append(bookmark)
    }

    /// Remove bookmark
    public func removeBookmark(id: UUID) {
        bookmarks.removeAll { $0.id == id }
    }

    /// Get bookmark at address
    public func getBookmark(at address: UInt32) -> MemoryBookmark? {
        bookmarks.first { $0.address == address }
    }

    /// Export memory region to file
    public func exportMemory(region: MemoryRegion, to url: URL) throws {
        var data = Data()

        for chunk in stride(from: region.startAddress, to: region.endAddress, by: chunkSize) {
            let chunkData = loadChunk(at: chunk)
            let remainingBytes = min(chunkSize, Int(region.endAddress - chunk + 1))
            data.append(Data(chunkData.prefix(remainingBytes)))
        }

        try data.write(to: url)
    }

    /// Import data from file
    public func importMemory(from url: URL, to address: UInt32) throws {
        let data = try Data(contentsOf: url)
        let bytes = Array(data)
        _ = writeMemory(at: address, data: bytes)
    }

    /// Get memory statistics
    public func getMemoryStatistics() -> MemoryStatistics {
        var stats = MemoryStatistics()

        for region in memoryRegions {
            stats.totalSize += region.size
            if region.permissions.contains(.read) {
                stats.readableSize += region.size
            }
            if region.permissions.contains(.write) {
                stats.writableSize += region.size
            }
            if region.permissions.contains(.execute) {
                stats.executableSize += region.size
            }
        }

        stats.loadedChunks = loadedChunks.count
        stats.bookmarkCount = bookmarks.count

        return stats
    }

    // MARK: - Display Methods

    /// Get formatted hex display
    public func getHexDisplay(address: UInt32, length: Int) -> [HexLine] {
        let data = getMemoryData(at: address, length: length)
        var lines: [HexLine] = []

        for i in stride(from: 0, to: data.count, by: bytesPerLine) {
            let lineAddress = address + UInt32(i)
            let endIndex = min(i + bytesPerLine, data.count)
            let lineData = Array(data[i..<endIndex])

            let hexBytes = lineData.enumerated().map { index, byte in
                HexByte(
                    offset: index,
                    value: byte,
                    isModified: false,
                    isBookmarked: getBookmark(at: lineAddress + UInt32(index)) != nil
                )
            }

            let asciiChars = lineData.map { byte in
                (byte >= 32 && byte <= 126) ? Character(UnicodeScalar(byte)) : "."
            }

            lines.append(HexLine(
                address: lineAddress,
                bytes: hexBytes,
                ascii: String(asciiChars),
                bookmark: getBookmark(at: lineAddress)
            ))
        }

        return lines
    }

    /// Get formatted disassembly display
    public func getDisassemblyDisplay(address: UInt32, length: Int) -> [DisassemblyLine] {
        // This would require integration with CPU debugger
        return []
    }

    // MARK: - Private Methods

    private func setupMemoryRegions() {
        // These would be populated based on the specific system
        memoryRegions = [
            MemoryRegion(
                name: "RAM",
                startAddress: 0x80000000,
                endAddress: 0x807FFFFF,
                permissions: [.read, .write],
                description: "Main system RAM"
            ),
            MemoryRegion(
                name: "ROM",
                startAddress: 0x90000000,
                endAddress: 0x9FFFFFFF,
                permissions: [.read, .execute],
                description: "Cartridge ROM"
            ),
            MemoryRegion(
                name: "MMIO",
                startAddress: 0xA0000000,
                endAddress: 0xBFFFFFFF,
                permissions: [.read, .write],
                description: "Memory-mapped I/O"
            )
        ]
    }

    private func refreshMemoryRegions() {
        // Update memory regions based on current system state
        // This would query the emulator core for actual memory layout
    }

    private func loadMemoryAtAddress(_ address: UInt32) {
        let alignedAddress = address & ~UInt32(chunkSize - 1)
        let chunk = loadChunk(at: alignedAddress)

        let offset = Int(address - alignedAddress)
        let length = min(chunkSize - offset, 1024) // Display up to 1KB

        memoryData = Array(chunk[offset..<offset + length])
    }

    private func loadChunk(at address: UInt32) -> [UInt8] {
        let chunkAddress = address & ~UInt32(chunkSize - 1)

        if let cached = loadedChunks[chunkAddress] {
            return cached
        }

        // Load from emulator core
        var chunk = Array(repeating: UInt8(0), count: chunkSize)

        if emulatorCore != nil {
            // This would read from the actual emulator
            // For now, fill with dummy data
            for i in 0..<chunkSize {
                chunk[i] = UInt8((chunkAddress + UInt32(i)) & 0xFF)
            }
        }

        loadedChunks[chunkAddress] = chunk
        return chunk
    }

    private func getMemoryData(at address: UInt32, length: Int) -> [UInt8] {
        var data: [UInt8] = []
        var currentAddr = address
        var remaining = length

        while remaining > 0 {
            let chunk = loadChunk(at: currentAddr)
            let chunkAddress = currentAddr & ~UInt32(chunkSize - 1)
            let offset = Int(currentAddr - chunkAddress)
            let copyLength = min(remaining, chunkSize - offset)

            data.append(contentsOf: chunk[offset..<offset + copyLength])

            currentAddr += UInt32(copyLength)
            remaining -= copyLength
        }

        return data
    }

    private func performPatternSearch(_ pattern: [UInt8], in region: MemoryRegion) -> [SearchResult] {
        var results: [SearchResult] = []
        let searchSize = 4096

        for address in stride(from: region.startAddress, to: region.endAddress, by: searchSize) {
            let data = getMemoryData(at: address, length: searchSize)

            for i in 0...(data.count - pattern.count) {
                let slice = Array(data[i..<i + pattern.count])
                if slice == pattern {
                    let resultAddress = address + UInt32(i)
                    let context = String(data[max(0, i - 8)..<min(data.count, i + pattern.count + 8)]
                                        .map { String(format: "%02X", $0) }
                                        .joined(separator: " "))

                    results.append(SearchResult(
                        address: resultAddress,
                        data: pattern,
                        context: context
                    ))
                }
            }
        }

        return results
    }
}

// MARK: - Supporting Types

public struct HexLine {
    public let address: UInt32
    public let bytes: [HexByte]
    public let ascii: String
    public let bookmark: MemoryViewer.MemoryBookmark?
}

public struct HexByte {
    public let offset: Int
    public let value: UInt8
    public let isModified: Bool
    public let isBookmarked: Bool

    public var hexString: String {
        String(format: "%02X", value)
    }
}

// DisassemblyLine is defined in CoreInterface

public struct MemoryStatistics {
    public var totalSize: UInt32 = 0
    public var readableSize: UInt32 = 0
    public var writableSize: UInt32 = 0
    public var executableSize: UInt32 = 0
    public var loadedChunks: Int = 0
    public var bookmarkCount: Int = 0
}

// MARK: - Memory Viewer Extensions

public extension MemoryViewer {

    /// Find memory region containing address
    func findRegion(containing address: UInt32) -> MemoryRegion? {
        memoryRegions.first { region in
            address >= region.startAddress && address <= region.endAddress
        }
    }

    /// Navigate to next search result
    func goToNextSearchResult() {
        guard !searchResults.isEmpty else { return }

        if let currentIndex = searchResults.firstIndex(where: { $0.address > currentAddress }) {
            goToAddress(searchResults[currentIndex].address)
        } else {
            goToAddress(searchResults[0].address)
        }
    }

    /// Navigate to previous search result
    func goToPreviousSearchResult() {
        guard !searchResults.isEmpty else { return }

        if let currentIndex = searchResults.lastIndex(where: { $0.address < currentAddress }) {
            goToAddress(searchResults[currentIndex].address)
        } else {
            goToAddress(searchResults.last!.address)
        }
    }

    /// Calculate checksum for memory region
    func calculateChecksum(for region: MemoryRegion) -> UInt32 {
        var checksum: UInt32 = 0

        for address in stride(from: region.startAddress, to: region.endAddress, by: 4) {
            let data = getMemoryData(at: address, length: 4)
            let value = data.withUnsafeBytes { $0.load(as: UInt32.self) }
            checksum = checksum.addingReportingOverflow(value).partialValue
        }

        return checksum
    }
}
