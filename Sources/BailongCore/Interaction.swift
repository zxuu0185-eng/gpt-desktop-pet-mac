import Foundation

public enum ContextEstimate {
    public static func remaining(input:Int64?,capacity:Int64?,stale:Bool) -> Int64? {
        guard !stale,let input,let capacity,input >= 0,capacity > 0,input <= capacity else { return nil }
        return capacity - input
    }
}
public struct MonologueClock {
    private var due:Date
    private var suspended = false
    private var interval:TimeInterval
    public init(now:Date,interval:TimeInterval) { self.interval = interval;due = now.addingTimeInterval(interval) }
    public mutating func reset(now:Date,interval:TimeInterval) { self.interval = interval;due = now.addingTimeInterval(interval);suspended = false }
    public mutating func tick(now:Date,enabled:Bool,blocked:Bool,visible:Bool) -> Bool {
        guard enabled && visible else { suspended = true;due = now.addingTimeInterval(interval);return false }
        if suspended { suspended = false;due = now.addingTimeInterval(interval);return false }
        guard !blocked,now >= due else { return false }
        due = now.addingTimeInterval(interval);return true
    }
}
public enum SessionMatcher {
    public static func match(title:String,candidates:[SessionSnapshot]) -> String? {
        let exact = candidates.filter { !$0.isChild && $0.title == title }
        return exact.count == 1 ? exact.first?.id:nil
    }
}
public struct PetPreferences:Codable {
    public var monologueEnabled = true
    public var intervalMinutes:Double = 15
    public var durationSeconds:Double = 5
    public var lines = ["干翻Claude","GPT世界第一","Altman是个外行"]
    public var randomLines = true
    public var imagePath:String?
    public var soundEnabled = true
    public var volume:Double = 0.3
    public var clickSound = "Pop"
    public var customSoundPath:String?
    public var completionSound = "Glass"
    public var idleAction = "idle"
    public var workAction = "work02"
    public var clickAction = "01"
    public var completionAction = "18"
    public var bubblesMuted = false
    public init() {}
}
public enum ResetGate {
    public static func canRequest(available:Int?,pendingKey:String?,busy:Bool) -> Bool {
        !busy && ((available ?? 0) > 0 || pendingKey != nil)
    }
}
