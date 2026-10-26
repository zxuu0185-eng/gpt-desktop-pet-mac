import Foundation

public struct PetLogEvent {
    public enum Kind:String { case message, memory, tool }
    public let kind:Kind
    public let key:String
    public let at:Date?
    public let action:String?
}
public struct LowQuotaGate:Codable {
    private var alerted:Set<String> = []
    public init() {}
    public mutating func observe(id:String,remaining:Double,reset:TimeInterval?) -> Bool {
        guard remaining.isFinite,remaining >= 0,remaining <= 10 else { return false }
        let key = id + ":" + (reset.map { String(Int($0)) } ?? "unknown")
        return alerted.insert(key).inserted
    }
}
