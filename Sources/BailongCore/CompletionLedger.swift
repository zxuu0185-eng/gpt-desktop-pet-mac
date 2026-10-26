import Foundation
public struct CompletionLedger {
    private var known:Set<String>
    private var pending:Set<String>
    private var baseline = false
    public private(set) var newlyPendingSessions:Set<String> = []
    public private(set) var acknowledged:Set<String>
    private static func session(_ key:String) -> String { String(key.split(separator:":",maxSplits:1).first ?? "") }
    public init(acknowledged:Set<String>=[],pending:Set<String>=[]) {
        self.acknowledged = acknowledged
        known = acknowledged.union(pending)
        var unique:[String:String] = [:]
        for key in pending.subtracting(acknowledged).sorted() { unique[Self.session(key)] = key }
        self.pending = Set(unique.values)
    }
    public mutating func observe(_ keys:[String]) -> [String] {
        newlyPendingSessions = []
        let current = Set(keys)
        defer { known.formUnion(current);baseline = true }
        guard baseline else { return pending.sorted() }
        for key in keys where !known.contains(key) && !acknowledged.contains(key) {
            let session = Self.session(key)
            if !pending.contains(where:{Self.session($0) == session}) { newlyPendingSessions.insert(session) }
            pending = pending.filter { Self.session($0) != session }
            pending.insert(key)
        }
        return pending.sorted()
    }
    public mutating func acknowledge(_ key:String) {
        let session = Self.session(key)
        acknowledged.formUnion(known.filter { Self.session($0) == session })
        acknowledged.formUnion(pending.filter { Self.session($0) == session })
        pending = pending.filter { Self.session($0) != session }
    }
}
