import Foundation

/// Where flashCK keeps its files. Tests pass a temp folder.
public struct DataPaths: Equatable, Sendable {
    public let folder: URL
    public var libraryURL: URL { folder.appendingPathComponent("library.json") }
    /// Launch snapshots of library.json (see `LibraryStore.backup`).
    public var backupsFolder: URL { folder.appendingPathComponent("backups", isDirectory: true) }
    public var preferencesURL: URL { folder.appendingPathComponent("preferences.json") }

    public init(folder: URL) { self.folder = folder }

    /// ~/Library/Application Support/flashCK
    public static var standard: DataPaths {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return DataPaths(folder: support.appendingPathComponent("flashCK", isDirectory: true))
    }
}

public enum LibraryStoreError: Error, Equatable, Sendable, LocalizedError {
    case unreadable(underlying: String)
    case newerSchema(Int)

    public var errorDescription: String? {
        switch self {
        case .unreadable(let underlying):
            return "The library file could not be read: \(underlying)"
        case .newerSchema(let n):
            return "The library was saved by a newer version of flashCK (schema \(n), this version reads \(Library.currentSchema)). Update flashCK to open it."
        }
    }
}

public struct LibraryStore: Sendable {
    public let paths: DataPaths

    public init(paths: DataPaths = .standard) { self.paths = paths }

    private struct Header: Decodable { var schemaVersion: Int }

    /// nil when there is no library yet. `migrated` is true for a file from an older schema, which
    /// should be saved so the conversion (and any new "Unsorted" subject ID) sticks. Never writes anything.
    public func load() throws -> (library: Library, migrated: Bool)? {
        let url = paths.libraryURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data: Data
        do { data = try Data(contentsOf: url) } catch {
            throw LibraryStoreError.unreadable(underlying: error.localizedDescription)
        }
        let decoder = JSONDecoder()
        let header: Header
        do { header = try decoder.decode(Header.self, from: data) } catch {
            throw LibraryStoreError.unreadable(underlying: String(describing: error))
        }
        if header.schemaVersion > Library.currentSchema { throw LibraryStoreError.newerSchema(header.schemaVersion) }
        let library: Library
        do { library = try decoder.decode(Library.self, from: data) } catch {
            throw LibraryStoreError.unreadable(underlying: String(describing: error))
        }
        return (library, header.schemaVersion < Library.currentSchema)
    }

    /// How many launch snapshots `backup` keeps.
    public static let keptBackups = 10

    /// Snapshot files in `backupsFolder`, oldest first. Other files there are ignored.
    public func backups() throws -> [URL] {
        let folder = paths.backupsFolder
        guard FileManager.default.fileExists(atPath: folder.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("library-") && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Snapshots library.json into `backups/library-<UTC time>Z.json`, unless it matches the newest
    /// snapshot, then keeps the newest `keptBackups`. No-op when there is no library.
    public func backup(at date: Date = Date()) throws {
        guard FileManager.default.fileExists(atPath: paths.libraryURL.path) else { return }
        let data = try Data(contentsOf: paths.libraryURL)
        var snapshots = try backups()
        // An unreadable newest snapshot counts as different, so a fresh one is written.
        if snapshots.last.flatMap({ try? Data(contentsOf: $0) }) != data {
            try FileManager.default.createDirectory(at: paths.backupsFolder, withIntermediateDirectories: true)
            let url = paths.backupsFolder.appendingPathComponent("library-\(Self.stamp(date))Z.json")
            try data.write(to: url, options: .atomic)
            snapshots = try backups()
        }
        for old in snapshots.dropLast(Self.keptBackups) { try FileManager.default.removeItem(at: old) }
    }

    /// UTC, so names sort in time order with no daylight-saving repeats.
    private static func stamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        return f.string(from: date)
    }

    public func save(_ library: Library) throws {
        try FileManager.default.createDirectory(at: paths.folder, withIntermediateDirectories: true)
        try encodeJSON(library).write(to: paths.libraryURL, options: .atomic)
    }
}

func encodeJSON<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(value)
}
