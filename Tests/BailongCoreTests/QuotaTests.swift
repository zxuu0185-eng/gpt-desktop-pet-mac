import Foundation
import Darwin
import BailongCore
final class QuotaTests {
    func testNamedBucketsAndMissingWindowArePreserved() throws {
        let data = Data(#"{"rateLimits":{"primary":{"usedPercent":25,"windowDurationMins":300,"resetsAt":1800000000}},"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":120,"windowDurationMins":300},"secondary":{"usedPercent":10,"windowDurationMins":10080}}}}"#.utf8)
        let snapshot = try QuotaSnapshot.decode(data)
        XCTAssertEqual(snapshot.windows.count,2)
        XCTAssertEqual(snapshot.windows[0].remainingPercent,0)
        XCTAssertEqual(snapshot.windows[1].durationMinutes,10080)
    }
    func testMissingUsageIsNotZero() throws {
        let snapshot = try QuotaSnapshot.decode(Data(#"{"rateLimits":{"primary":{"windowDurationMins":300}}}"#.utf8))
        XCTAssertTrue(snapshot.windows.isEmpty)
    }
    func testTimeoutTerminatesOwnedProcess() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:dir) }
        let pid = dir.appendingPathComponent("pid")
        let executable = dir.appendingPathComponent("silent-server")
        try Data("#!/bin/sh\nprintf '%s' $$ > '\(pid.path)'\nexec /bin/sleep 10\n".utf8).write(to:executable)
        try FileManager.default.setAttributes([.posixPermissions:0o700],ofItemAtPath:executable.path)
        let start = Date()
        do { _ = try QuotaClient().read(executable:executable,timeout:1.2);XCTAssertTrue(false) }
        catch QuotaError.timeout {} catch { print("Unexpected fixture error: \(error)");XCTAssertTrue(false) }
        XCTAssertLessThan(Date().timeIntervalSince(start),3)
        guard let contents = try? String(contentsOf:pid,encoding:.utf8),let processID = Int32(contents) else { print("fixture did not write pid");XCTAssertTrue(false);return }
        XCTAssertEqual(kill(processID,0),-1)
    }
    func testCancellationBeforeStartDoesNotLaunchProcess() {
        let client = QuotaClient()
        client.cancel()
        do { _ = try client.read(executable:URL(fileURLWithPath:"/bin/sleep"),timeout:0.2);XCTAssertTrue(false) }
        catch QuotaError.cancelled {} catch { XCTAssertTrue(false) }
    }
}
