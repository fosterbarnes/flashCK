import Foundation

/// What still has to reach disk. The library is written only once this launch's backup exists, so a
/// failed backup is never replaced by this session's edits. A failed write stays pending for the next flush.
public struct PendingWrites: Equatable, Sendable {
    /// Snapshot library.json into backups/ before the first library write of this launch.
    public var backup: Bool
    public var library = false
    public var preferences = false

    public init(backup: Bool = false) { self.backup = backup }

    /// Writes what is pending; returns one message per write that failed or had to wait.
    public mutating func flush(_ current: Library, _ prefs: Preferences, libraryStore: LibraryStore,
                               preferencesStore: PreferencesStore) -> [String] {
        var errors: [String] = []
        if backup {
            do {
                try libraryStore.backup()
                backup = false
            } catch {
                errors.append("Backup failed: \(error.localizedDescription)")
            }
        }
        if library {
            if backup {
                errors.append("Library not saved: it waits until the backup succeeds.")
            } else {
                do {
                    try libraryStore.save(current)
                    library = false
                } catch {
                    errors.append("Library not saved: \(error.localizedDescription)")
                }
            }
        }
        if preferences {
            do {
                try preferencesStore.save(prefs)
                preferences = false
            } catch {
                errors.append("Preferences not saved: \(error.localizedDescription)")
            }
        }
        return errors
    }
}
