import Foundation
import CArchive

public struct ArchiveEntry: Equatable {
    public var path: String
    public var isDirectory: Bool
    public var isSymlink: Bool
    public var size: Int64?
    public var modified: Date?
    public var isEncrypted: Bool

    public init(path: String, isDirectory: Bool = false, isSymlink: Bool = false,
                size: Int64? = nil, modified: Date? = nil, isEncrypted: Bool = false) {
        self.path = path
        self.isDirectory = isDirectory
        self.isSymlink = isSymlink
        self.size = size
        self.modified = modified
        self.isEncrypted = isEncrypted
    }
}

public struct ArchiveListing {
    public var entries: [ArchiveEntry]
    /// libarchive's description, e.g. "ZIP 2.0 (deflation)" or "POSIX ustar format".
    public var formatName: String
    /// Compression filters wrapped around the archive, outermost first, e.g. ["gzip"].
    public var filters: [String]
    /// Entries that were read but not kept because `maxEntries` was reached.
    public var omittedCount: Int
    /// Set when reading stopped early because of an error after some entries were read.
    public var warning: String?
}

public struct ArchiveError: Error, CustomStringConvertible {
    public var description: String
}

public enum ArchiveReader {
    /// Skip macOS resource-fork noise (`__MACOSX/`, `._name`) added by Finder's "Compress".
    public static var hidesAppleDouble = true

    /// Reads only the entry headers (no data is extracted).
    /// Entries past `maxEntries` are counted but not kept.
    public static func list(url: URL, maxEntries: Int = 10_000) throws -> ArchiveListing {
        do {
            return try read(url: url, maxEntries: maxEntries, raw: false)
        } catch let error as ArchiveError {
            // Plain compressed files (foo.txt.gz, foo.bz2) are not archives; show their single member.
            if let listing = try? read(url: url, maxEntries: maxEntries, raw: true), !listing.filters.isEmpty {
                return listing
            }
            throw error
        }
    }

    private static func read(url: URL, maxEntries: Int, raw: Bool) throws -> ArchiveListing {
        guard let archive = archive_read_new() else {
            throw ArchiveError(description: "Could not initialize libarchive.")
        }
        defer { archive_read_free(archive) }

        archive_read_support_filter_all(archive)
        if raw {
            archive_read_support_format_raw(archive)
        } else {
            archive_read_support_format_all(archive)
        }

        guard archive_read_open_filename(archive, url.path, 64 * 1024) == ARCHIVE_OK else {
            throw ArchiveError(description: errorString(archive))
        }

        var entries: [ArchiveEntry] = []
        var omitted = 0
        var warning: String?

        loop: while true {
            var entry: OpaquePointer?
            switch archive_read_next_header(archive, &entry) {
            case ARCHIVE_EOF:
                break loop
            case ARCHIVE_OK, ARCHIVE_WARN:
                break
            case ARCHIVE_RETRY:
                continue loop
            default:
                if entries.isEmpty && omitted == 0 { throw ArchiveError(description: errorString(archive)) }
                warning = errorString(archive)
                break loop
            }
            guard let entry else { break loop }

            if raw {
                // The raw format names its single member "data"; use the file name minus the compression suffix.
                let name = url.deletingPathExtension().lastPathComponent
                let size: Int64? = archive_entry_size_is_set(entry) != 0 ? archive_entry_size(entry) : nil
                entries.append(ArchiveEntry(path: name, size: size))
                break loop
            }

            if var parsed = makeEntry(entry) {
                if entries.count < maxEntries {
                    parsed.path = normalize(parsed.path)
                    if !parsed.path.isEmpty && !isHidden(parsed.path) {
                        entries.append(parsed)
                    }
                } else {
                    omitted += 1
                }
            }
            if archive_read_data_skip(archive) == ARCHIVE_FATAL {
                warning = errorString(archive)
                break loop
            }
        }

        let filterCount = archive_filter_count(archive)
        let filters = (0..<filterCount).compactMap { index -> String? in
            guard let name = archive_filter_name(archive, index).map({ String(cString: $0) }),
                  name != "none" else { return nil }
            return name
        }

        return ArchiveListing(
            entries: entries,
            formatName: archive_format_name(archive).map { String(cString: $0) } ?? "Unknown",
            filters: filters,
            omittedCount: omitted,
            warning: warning
        )
    }

    private static func makeEntry(_ entry: OpaquePointer) -> ArchiveEntry? {
        guard let cPath = archive_entry_pathname_utf8(entry) ?? archive_entry_pathname(entry) else {
            return nil
        }
        let type = archive_entry_filetype(entry) & AE_IFMT
        let isDirectory = type == AE_IFDIR
        let size: Int64? = !isDirectory && archive_entry_size_is_set(entry) != 0 ? archive_entry_size(entry) : nil
        let modified: Date? = archive_entry_mtime_is_set(entry) != 0
            ? Date(timeIntervalSince1970: TimeInterval(archive_entry_mtime(entry)))
            : nil
        var path = String(cString: cPath)
        // Some archivers mark directories only by a trailing slash.
        let slashDirectory = path.hasSuffix("/")
        if slashDirectory { path.removeLast() }
        return ArchiveEntry(
            path: path,
            isDirectory: isDirectory || slashDirectory,
            isSymlink: type == AE_IFLNK,
            size: size,
            modified: modified,
            isEncrypted: archive_entry_is_encrypted(entry) != 0
        )
    }

    static func normalize(_ path: String) -> String {
        path.split(separator: "/", omittingEmptySubsequences: true)
            .filter { $0 != "." }
            .joined(separator: "/")
    }

    static func isHidden(_ path: String) -> Bool {
        guard hidesAppleDouble else { return false }
        return path == "__MACOSX" || path.hasPrefix("__MACOSX/")
            || path.split(separator: "/").last?.hasPrefix("._") == true
    }

    private static func errorString(_ archive: OpaquePointer) -> String {
        archive_error_string(archive).map { String(cString: $0) } ?? "Unknown error while reading archive."
    }
}
