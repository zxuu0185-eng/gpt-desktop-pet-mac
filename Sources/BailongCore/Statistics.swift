import Foundation
import CoreFoundation

public enum SessionLink {
    public static func url(_ id:String) -> URL? {
        guard UUID(uuidString:id) != nil, id.count == 36 else { return nil }
        return URL(string:"codex://threads/" + id.lowercased())
    }
}
public struct UsageRecord:Identifiable {
    public let id:String
    public let date:Date
    public let model:String
    public let input:Int64
    public let cached:Int64
    public let output:Int64
    public let total:Int64
}
/// Retains accounting fields only, never prompts, tool output or response text.
public final class UsageAccumulator {
    public private(set) var records:[String:UsageRecord] = [:]
    public private(set) var skipped = 0
    public private(set) var hasLegacy = false
    private var pending = Data()
    private var model = "未知模型"
    private let fractional:ISO8601DateFormatter = { let f = ISO8601DateFormatter();f.formatOptions = [.withInternetDateTime,.withFractionalSeconds];return f }()
    private let plain = ISO8601DateFormatter()
    public init() {}
    public func consume(_ data:Data) {
        pending.append(data)
        while let end = pending.firstIndex(of:10) {
            let line = pending.prefix(upTo:end)
            if line.range(of:Data("token_usage_record".utf8)) != nil || line.range(of:Data("turn_context".utf8)) != nil || line.range(of:Data("token_count".utf8)) != nil {
                parse(Data(line))
            }
            pending.removeSubrange(...end)
        }
        if pending.count > 8 * 1024 * 1024 { pending.removeAll();skipped += 1 }
    }
    private func parse(_ data:Data) {
        guard let obj = try? JSONSerialization.jsonObject(with:data) as? [String:Any],let type = obj["type"] as? String,let p = obj["payload"] as? [String:Any] else { return }
        if type == "turn_context" { model = p["model"] as? String ?? "未知模型";return }
        if type != "token_usage_record" { if p["type"] as? String == "token_count" { hasLegacy = true };return }
        func count(_ value:Any?) -> Int64? {
            guard let n = value as? NSNumber,CFGetTypeID(n) != CFBooleanGetTypeID(),n.doubleValue >= 0,n.doubleValue < Double(Int64.max),n.doubleValue.rounded() == n.doubleValue else { return nil };return n.int64Value
        }
        guard let id = p["response_id"] as? String,!id.isEmpty,let time = obj["timestamp"] as? String,let date = fractional.date(from:time) ?? plain.date(from:time),let usage = p["usage"] as? [String:Any],let input = count(usage["input_tokens"]),let cached = count(usage["cached_input_tokens"]),let output = count(usage["output_tokens"]),let total = count(usage["total_tokens"]),cached <= input else { skipped += 1;return }
        records[id] = UsageRecord(id:id,date:date,model:model,input:input,cached:cached,output:output,total:total)
    }
}
/// Queue confined incremental index. Replacements and truncation discard the old file's contribution.
public final class StatisticsIndex {
    private struct FileState { var offset:UInt64 = 0;var inode:UInt64 = 0;var prefix = Data();var boundary = Data();var accumulator = UsageAccumulator() }
    private var files:[URL:FileState] = [:]
    public init() {}
    public func refresh(root:URL) -> (records:[UsageRecord],legacy:Int,skipped:Int,unreadable:Int) {
        var urls:[URL] = []
        for name in ["sessions","archived_sessions"] {
            if let enumerator = FileManager.default.enumerator(at:root.appendingPathComponent(name),includingPropertiesForKeys:nil,options:.skipsHiddenFiles) {
                for case let url as URL in enumerator where url.pathExtension == "jsonl" { urls.append(url) }
            }
        }
        let keep = Set(urls);files = files.filter { keep.contains($0.key) }
        var unreadable = 0
        for url in urls.sorted(by:{$0.path < $1.path}) {
            do { try read(url) } catch { unreadable += 1 }
        }
        var unique:[String:UsageRecord] = [:]
        var legacy = 0;var skipped = 0
        for url in urls.sorted(by:{$0.path < $1.path}) {
            guard let a = files[url]?.accumulator else { continue }
            if a.hasLegacy && a.records.isEmpty { legacy += 1 }
            skipped += a.skipped
            for (id,r) in a.records where unique[id] == nil { unique[id] = r }
        }
        return (unique.values.sorted {$0.date < $1.date},legacy,skipped,unreadable)
    }
    private func read(_ url:URL) throws {
        let attrs = try FileManager.default.attributesOfItem(atPath:url.path)
        let size = (attrs[.size] as? NSNumber)?.uint64Value ?? 0
        let inode = (attrs[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
        let h = try FileHandle(forReadingFrom:url);defer { try? h.close() }
        let prefix = try h.read(upToCount:Int(min(size,128))) ?? Data()
        var state = files[url] ?? FileState()
        var changed = false
        if size >= state.offset && !state.boundary.isEmpty {
            try h.seek(toOffset:state.offset - UInt64(state.boundary.count));changed = (try h.read(upToCount:state.boundary.count)) != state.boundary
        }
        let overlap = min(prefix.count,state.prefix.count)
        if changed || size < state.offset || (state.inode != 0 && inode != state.inode) || prefix.prefix(overlap) != state.prefix.prefix(overlap) { state = FileState() }
        state.inode = inode;state.prefix = prefix
        try h.seek(toOffset:state.offset)
        while state.offset < size {
            let data = try h.read(upToCount:Int(min(1024 * 1024,size - state.offset))) ?? Data()
            if data.isEmpty { break };state.accumulator.consume(data);state.offset += UInt64(data.count)
        }
        let n = min(state.offset,128);try h.seek(toOffset:state.offset - n);state.boundary = try h.read(upToCount:Int(n)) ?? Data()
        files[url] = state
    }
}
