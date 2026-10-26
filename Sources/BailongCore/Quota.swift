import Foundation
import Darwin

public struct QuotaWindow: Identifiable {
    public let id: String
    public let usedPercent: Double
    public let durationMinutes: Int?
    public let resetsAt: Date?
    public var remainingPercent:Double { max(0,min(100,100-usedPercent)) }
    public var label:String {
        guard let durationMinutes else { return "未知周期" }
        if durationMinutes == 10080 { return "每周" }
        if durationMinutes % 60 == 0 { return "\(durationMinutes / 60) 小时" }
        return "\(durationMinutes) 分钟"
    }
}
public enum ResetOutcome:String {
    case reset,alreadyRedeemed,nothingToReset,noCredit
    public static func decode(_ object:[String:Any]) throws -> ResetOutcome {
        guard let text = object["outcome"] as? String,let outcome = ResetOutcome(rawValue:text) else { throw QuotaError.invalidResponse };return outcome
    }
}
public struct ResetCredit:Identifiable {
    public let id:String
    public let title:String?
    public let expiresAt:Date?
}
public struct QuotaSnapshot {
    public let resetAvailable:Int?
    public let resetCredits:[ResetCredit]
    public let windows:[QuotaWindow]
    public let date:Date
    public static func decode(_ data:Data) throws -> QuotaSnapshot {
        guard let object = try JSONSerialization.jsonObject(with:data) as? [String:Any] else { throw QuotaError.invalidResponse }
        var result:[QuotaWindow] = []
        let buckets = object["rateLimitsByLimitId"] as? [String:[String:Any]]
        let sources:[String:[String:Any]]
        if let buckets, !buckets.isEmpty { sources = buckets }
        else if let legacy = object["rateLimits"] as? [String:Any] { sources = ["codex":legacy] }
        else { sources = [:] }
        for key in sources.keys.sorted() {
            for name in ["primary","secondary"] {
                guard let item = sources[key]?[name] as? [String:Any], let used = item["usedPercent"] as? Double, used.isFinite, used >= 0 else { continue }
                let mins = item["windowDurationMins"] as? Int
                let reset = (item["resetsAt"] as? Double).flatMap { $0 > 0 ? Date(timeIntervalSince1970:$0) : nil }
                result.append(QuotaWindow(id:key + ":" + name,usedPercent:used,durationMinutes:mins.flatMap { $0 > 0 ? $0:nil },resetsAt:reset))
            }
        }
        let reset = object["rateLimitResetCredits"] as? [String:Any]
        let available = (reset?["availableCount"] as? Int).flatMap { $0 >= 0 ? $0:nil }
        let credits = (reset?["credits"] as? [[String:Any]] ?? []).compactMap { item -> ResetCredit? in
            guard let id = item["id"] as? String,item["status"] as? String == "available" else { return nil }
            return ResetCredit(id:id,title:item["title"] as? String,expiresAt:(item["expiresAt"] as? Double).map { Date(timeIntervalSince1970:$0) })
        }
        return QuotaSnapshot(resetAvailable:available,resetCredits:credits,windows:result,date:Date())
    }
}
public enum QuotaError: LocalizedError {
    case invalidResponse, timeout, processExited, notFound, serverError, cancelled
    public var errorDescription:String? {
        switch self {
        case .cancelled: return "连接已取消"
        case .invalidResponse: return "额度返回格式无法识别"
        case .timeout: return "Codex 连接超时，未取得新额度"
        case .processExited: return "Codex 数据进程提前退出，请检查本机 Codex 是否正常"
        case .notFound: return "找不到 Codex 可执行文件，请在设置中指定"
        case .serverError: return "Codex 未能返回额度，请确认已登录"
        }
    }
}
public final class QuotaClient {
    private let lock = NSLock()
    private var active:Process?
    private var cancelled = false
    public init() {}
    public func cancel() {
        lock.lock(); cancelled = true
        if let process = active, process.isRunning { kill(process.processIdentifier,SIGKILL) }
        lock.unlock()
    }
    public static func discover(custom:String?=nil) -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [custom,home.appendingPathComponent(".local/bin/codex").path,"/Applications/Codex.app/Contents/Resources/codex","/Applications/ChatGPT.app/Contents/Resources/codex","/opt/homebrew/bin/codex","/usr/local/bin/codex"].compactMap { $0 }
        return candidates.first { FileManager.default.isExecutableFile(atPath:$0) }.map { URL(fileURLWithPath:$0) }
    }
    public func read(executable:URL,timeout:TimeInterval=12) throws -> QuotaSnapshot {
        let result = try request(executable:executable,method:"account/rateLimits/read",params:[:],timeout:timeout)
        return try QuotaSnapshot.decode(JSONSerialization.data(withJSONObject:result))
    }
    public func consume(executable:URL,key:String,timeout:TimeInterval=12) throws -> ResetOutcome {
        guard UUID(uuidString:key) != nil else { throw QuotaError.invalidResponse }
        return try ResetOutcome.decode(request(executable:executable,method:"account/rateLimitResetCredit/consume",params:["idempotencyKey":key],timeout:timeout))
    }
    private func request(executable:URL,method:String,params:[String:Any],timeout:TimeInterval) throws -> [String:Any] {
        let process = Process(); let input = Pipe(); let output = Pipe()
        process.executableURL = executable; process.arguments = ["app-server","--stdio"]
        process.standardInput = input; process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        lock.lock()
        if cancelled { lock.unlock();throw QuotaError.cancelled }
        do { try process.run();active = process;lock.unlock() }
        catch { lock.unlock();throw error }
        _ = fcntl(input.fileHandleForWriting.fileDescriptor,F_SETNOSIGPIPE,1)
        defer {
            try? input.fileHandleForWriting.close()
            if process.isRunning { process.terminate() }
            let deadline = Date().addingTimeInterval(0.5)
            while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval:0.01) }
            if process.isRunning { kill(process.processIdentifier,SIGKILL) }
            process.waitUntilExit()
            lock.lock();active = nil;lock.unlock()
            try? output.fileHandleForReading.close()
        }
        let deadline = Date().addingTimeInterval(timeout)
        var pending = Data()
        func send(_ value:[String:Any]) throws {
            guard process.isRunning else { throw QuotaError.processExited }
            try input.fileHandleForWriting.write(contentsOf:JSONSerialization.data(withJSONObject:value) + Data([10]))
        }
        func response(_ id:Int) throws -> [String:Any] {
            while Date() < deadline {
                while let split = pending.firstIndex(of:10) {
                    let row = pending[..<split]; pending.removeSubrange(...split)
                    guard let object = try? JSONSerialization.jsonObject(with:row) as? [String:Any], object["id"] as? Int == id else { continue }
                    if object["error"] != nil { throw QuotaError.serverError }
                    guard let result = object["result"] as? [String:Any] else { throw QuotaError.invalidResponse }
                    return result
                }
                var descriptor = pollfd(fd:output.fileHandleForReading.fileDescriptor,events:Int16(POLLIN),revents:0)
                let ready = poll(&descriptor,1,100)
                if ready > 0 {
                    var buffer = [UInt8](repeating:0,count:8192)
                    let count = Darwin.read(descriptor.fd,&buffer,buffer.count)
                    guard count > 0 else { throw QuotaError.processExited }
                    pending.append(contentsOf:buffer.prefix(count))
                    guard pending.count < 2 * 1024 * 1024 else { throw QuotaError.invalidResponse }
                } else if !process.isRunning { throw QuotaError.processExited }
            }
            throw QuotaError.timeout
        }
        try send(["id":1,"method":"initialize","params":["clientInfo":["name":"bailong_mac","version":"0.3.0"]]])
        _ = try response(1)
        try send(["method":"initialized","params":[:]])
        try send(["id":2,"method":method,"params":params])
        return try response(2)
    }
}
