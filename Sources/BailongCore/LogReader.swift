import Foundation

/// Access from one background queue only. Bounds retained state to selected recent logs.
public final class LogReader {
    private struct Cursor {
        var offset: UInt64 = 0
        var inode: UInt64 = 0
        var prefix = Data()
        var boundary = Data()
        var accumulator = SessionAccumulator()
    }
    private var cursors: [URL: Cursor] = [:]
    private var petEvents:[PetLogEvent] = []
    public func drainPetEvents() -> [PetLogEvent] {
        defer { petEvents.removeAll(keepingCapacity:true) }
        return petEvents
    }
    private var completions:[CompletionEvent] = []
    public func drainCompletions() -> [CompletionEvent] {
        defer { completions.removeAll(keepingCapacity:true) }
        return completions
    }
    public init() {}
    public func retain(_ urls:[URL]) { let keys = Set(urls); cursors = cursors.filter { keys.contains($0.key) } }
    public func refresh(_ url:URL) throws -> SessionSnapshot {
        let attrs = try FileManager.default.attributesOfItem(atPath:url.path)
        let size = (attrs[.size] as? NSNumber)?.uint64Value ?? 0
        let inode = (attrs[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
        let handle = try FileHandle(forReadingFrom:url)
        defer { try? handle.close() }
        let prefix = try handle.read(upToCount:Int(min(size,128))) ?? Data()
        var cursor = cursors[url] ?? Cursor()
        // Compare only bytes already seen: a growing short first line is not a replacement.
        let overlap = min(prefix.count,cursor.prefix.count)
        var rewritten = false
        if cursor.offset >= UInt64(cursor.boundary.count), size >= cursor.offset, !cursor.boundary.isEmpty {
            try handle.seek(toOffset:cursor.offset - UInt64(cursor.boundary.count))
            rewritten = (try handle.read(upToCount:cursor.boundary.count)) != cursor.boundary
        }
        if rewritten || size < cursor.offset || (cursor.inode != 0 && inode != cursor.inode) || prefix.prefix(overlap) != cursor.prefix.prefix(overlap) {
            cursor = Cursor()
        }
        cursor.inode = inode; cursor.prefix = prefix
        try handle.seek(toOffset:cursor.offset)
        // Per-file budget avoids lengthy first scans monopolising the UI's data queue.
        let budget: UInt64 = 8 * 1024 * 1024
        let end = min(size,cursor.offset + budget)
        while cursor.offset < end {
            let data = try handle.read(upToCount:Int(min(256 * 1024,end - cursor.offset))) ?? Data()
            if data.isEmpty { break }
            cursor.accumulator.consume(data)
            cursor.offset += UInt64(data.count)
        }
        let boundaryCount = min(cursor.offset,128)
        try handle.seek(toOffset:cursor.offset - boundaryCount)
        cursor.boundary = try handle.read(upToCount:Int(boundaryCount)) ?? Data()
        petEvents.append(contentsOf:cursor.accumulator.drainPetEvents())
        completions.append(contentsOf:cursor.accumulator.drainCompletions())
        cursors[url] = cursor
        return cursor.accumulator.snapshot
    }
    public static func recentLogs(root:URL, limit:Int=12) -> [URL] {
        let fm = FileManager.default
        // Inspect metadata across dated folders so resumed older sessions remain discoverable; never read bodies here.
        func directories(_ url:URL) -> [URL] {
            ((try? fm.contentsOfDirectory(at:url,includingPropertiesForKeys:[.isDirectoryKey],options:.skipsHiddenFiles)) ?? [])
                .filter { (try? $0.resourceValues(forKeys:[.isDirectoryKey]).isDirectory) == true }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
        }
        var found:[URL] = []
        for year in directories(root) {
            for month in directories(year) {
                for day in directories(month) {
                    let files = ((try? fm.contentsOfDirectory(at:day,includingPropertiesForKeys:[.contentModificationDateKey],options:.skipsHiddenFiles)) ?? []).filter { $0.pathExtension == "jsonl" }
                    found.append(contentsOf:files)
                }
            }
        }
        return Array(found.sorted {
            let a = (try? $0.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a > b
        }.prefix(limit))
    }
}
