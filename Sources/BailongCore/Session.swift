import Foundation

public enum WorkState: String, Codable {
    case unknown, working, completed, interrupted, compacting, waiting
    public var label: String {
        switch self {
        case .unknown: return "暂无状态"
        case .working: return "工作中"
        case .completed: return "已完成"
        case .interrupted: return "已中断"
        case .compacting: return "压缩上下文"
        case .waiting: return "等待输入或审批"
        }
    }
}

public struct SessionSnapshot: Identifiable {
    public var id: String?
    public var origin = "未知来源"
    public var title = "未命名会话"
    public var model: String?
    public var state: WorkState = .unknown
    public var stateAt: Date?
    public var usageAt: Date?
    public var previousInput: Int64?
    public var cumulative: Int64?
    public var capacity: Int64?
    public var usageStale = false
    public var completedTurn: String?
    public var isChild = false
    public var cwd: String?
    public init() {}
    public var completionKey: String? {
        guard !isChild, state == .completed, let id, let completedTurn else { return nil }
        return id + ":" + completedTurn
    }
}

public struct CompletionEvent {
    public let key:String
    public let at:Date?
    public let isChild:Bool
}

public struct SessionAccumulator {
    public private(set) var snapshot = SessionSnapshot()
    private var petEvents:[PetLogEvent] = []
    public mutating func drainPetEvents() -> [PetLogEvent] {
        defer { petEvents.removeAll(keepingCapacity:true) }
        return petEvents
    }
    private var completions:[CompletionEvent] = []
    public mutating func drainCompletions() -> [CompletionEvent] {
        defer { completions.removeAll(keepingCapacity:true) }
        return completions
    }
    private var activeTurn: String?
    private var pending = Data()
    public init() {}

    public mutating func consume(_ data: Data) {
        pending.append(data)
        while let newline = pending.firstIndex(of:10) {
            let row = Data(pending[..<newline])
            pending.removeSubrange(...newline)
            parse(row)
        }
        // Never retain arbitrary oversized chat content or a permanently invalid line.
        if pending.count > 8 * 1024 * 1024 { pending.removeAll(keepingCapacity:false) }
    }
    private mutating func parse(_ data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with:data) as? [String:Any],
              let type = object["type"] as? String else { return }
        let p = object["payload"] as? [String:Any] ?? [:]
        let date = (object["timestamp"] as? String).flatMap(Self.date)
        switch type {
        case "session_meta":
            snapshot.id = p["id"] as? String ?? p["session_id"] as? String
            snapshot.origin = p["originator"] as? String ?? "未知来源"
            snapshot.cwd = p["cwd"] as? String
            if let cwd = snapshot.cwd { snapshot.title = URL(fileURLWithPath:cwd).lastPathComponent }
            if let source = p["source"] as? [String:Any], source["subagent"] != nil { snapshot.isChild = true }
        case "turn_context":
            if let model = p["model"] as? String {
                if let old = snapshot.model, old != model { snapshot.capacity = nil; snapshot.usageStale = true }
                snapshot.model = model
            }
        case "compacted":
            snapshot.usageStale = true
            snapshot.state = .compacting
            snapshot.stateAt = date
        case "response_item":
            if ["function_call","custom_tool_call"].contains(p["type"] as? String ?? ""),let name = p["name"] as? String {
                let lower = name.lowercased()
                let args = ((p["arguments"] as? String) ?? (p["input"] as? String) ?? "").lowercased()
                let fileTool = lower.contains("exec") || lower.contains("read") || lower.contains("write") || lower.contains("patch")
                let memoryPath = args.contains("/memory.md") || args.contains("/memories/") || args.contains("/memory/")
                let memory = lower.contains("memory") || lower.contains("memories") || (fileTool && memoryPath)
                let kind:PetLogEvent.Kind = memory ? .memory:.tool
                let action = memory ? "21":lower.contains("search") || lower.contains("find") ? "work05":lower.contains("read") || lower.contains("open") ? "work04":lower.contains("write") || lower.contains("patch") ? "work03":"work02"
                if let id = snapshot.id,let key = p["call_id"] as? String ?? object["timestamp"] as? String {
                    petEvents.append(PetLogEvent(kind:kind,key:id + ":" + kind.rawValue + ":" + key,at:date,action:action))
                }
            }
        case "event_msg":
            switch p["type"] as? String {
            case "token_count":
                guard let info = p["info"] as? [String:Any] else { return }
                if let last = info["last_token_usage"] as? [String:Any], let value = Self.nonnegative(last["input_tokens"]) {
                    snapshot.previousInput = value; snapshot.usageAt = date; snapshot.usageStale = false
                }
                if let total = info["total_token_usage"] as? [String:Any], let value = Self.nonnegative(total["total_tokens"]) { snapshot.cumulative = value }
                if let capacity = Self.nonnegative(info["model_context_window"]), capacity > 0 { snapshot.capacity = capacity }
            case "user_message":
                if let id = snapshot.id,let stamp = object["timestamp"] as? String {
                    petEvents.append(PetLogEvent(kind:.message,key:id + ":message:" + stamp,at:date,action:"04"))
                }
            case "task_started":
                activeTurn = p["turn_id"] as? String
                snapshot.state = .working; snapshot.stateAt = date
                snapshot.completedTurn = nil
            case "task_complete", "task_completed":
                snapshot.state = .completed; snapshot.stateAt = date
                snapshot.completedTurn = p["turn_id"] as? String ?? activeTurn
                if let id = snapshot.id, let turn = snapshot.completedTurn {
                    completions.append(CompletionEvent(key:id + ":" + turn,at:date,isChild:snapshot.isChild))
                }
            case "turn_aborted": snapshot.state = .interrupted; snapshot.stateAt = date; snapshot.completedTurn = nil
            case "context_compacted": snapshot.usageStale = true; snapshot.state = .compacting; snapshot.stateAt = date
            default: break
            }
        default: break
        }
    }
    static func nonnegative(_ value:Any?) -> Int64? {
        guard let n = value as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(), n.int64Value >= 0 else { return nil }
        return n.int64Value
    }
    static func date(_ text:String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime,.withFractionalSeconds]
        return formatter.date(from:text) ?? ISO8601DateFormatter().date(from:text)
    }
}
import CoreFoundation

public func tokenText(_ number:Int64?) -> String {
    guard let number else { return "未知" }
    return number.formatted(.number.grouping(.automatic))
}
