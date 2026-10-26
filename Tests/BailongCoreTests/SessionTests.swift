import Foundation
import BailongCore
final class SessionTests {
    func line(_ object: [String: Any]) -> Data { try! JSONSerialization.data(withJSONObject: object) + Data([10]) }
    func testPreviousInputIsSeparateFromCumulativeAndCapacityIsNotInvented() {
        var state = SessionAccumulator()
        state.consume(line(["type":"session_meta","payload":["id":"one","originator":"Codex Desktop"]]))
        state.consume(line(["type":"event_msg","timestamp":"2026-10-25T09:00:00Z","payload":["type":"token_count","info":["last_token_usage":["input_tokens":800,"output_tokens":50],"total_token_usage":["total_tokens":90000]]]]))
        XCTAssertEqual(state.snapshot.id, "one")
        XCTAssertEqual(state.snapshot.previousInput, 800)
        XCTAssertEqual(state.snapshot.cumulative, 90000)
        XCTAssertNil(state.snapshot.capacity)
    }
    func testCompactionInvalidatesOldReadoutUntilNewTokenEvent() {
        var state = SessionAccumulator()
        state.consume(line(["type":"event_msg","payload":["type":"token_count","info":["last_token_usage":["input_tokens":800],"model_context_window":2000]]]))
        state.consume(line(["type":"compacted","payload":[:]]))
        XCTAssertTrue(state.snapshot.usageStale)
        state.consume(line(["type":"event_msg","payload":["type":"token_count","info":["last_token_usage":["input_tokens":100],"model_context_window":2000]]]))
        XCTAssertFalse(state.snapshot.usageStale)
        XCTAssertEqual(state.snapshot.previousInput, 100)
    }
    func testCompletionUsesTurnIdentityAndDoesNotRetainTaskText() {
        var state = SessionAccumulator()
        state.consume(line(["type":"event_msg","payload":["type":"task_started","turn_id":"turn-1"]]))
        state.consume(line(["type":"event_msg","payload":["type":"task_complete","turn_id":"turn-1","last_agent_message":"PRIVATE"]]))
        XCTAssertEqual(state.snapshot.state, .completed)
        XCTAssertEqual(state.snapshot.completedTurn, "turn-1")
    }
    func testPartialWriteThenTruncation() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("log.jsonl")
        let full = line(["type":"session_meta","payload":["id":"first"]])
        try full.dropLast(3).write(to:file)
        let reader = LogReader()
        XCTAssertNil(try reader.refresh(file).id)
        try full.write(to:file)
        XCTAssertEqual(try reader.refresh(file).id, "first")
        try line(["type":"session_meta","payload":["id":"x"]]).write(to:file)
        XCTAssertEqual(try reader.refresh(file).id, "x")
    }
    func testReminderBaselineDeduplicatesAndSeparatesThreads() {
        var ledger = CompletionLedger()
        XCTAssertEqual(ledger.observe(["a:t1"]), [])
        XCTAssertEqual(ledger.observe(["a:t1","b:t1"]), ["b:t1"])
        XCTAssertEqual(ledger.observe(["a:t1","b:t1"]), ["b:t1"])
        ledger.acknowledge("b:t1")
        XCTAssertEqual(ledger.observe(["b:t1"]), [])
        XCTAssertEqual(ledger.observe(["b:t2"]), ["b:t2"])
    }
    func testModelChangeDoesNotKeepOldCapacity() {
        var state = SessionAccumulator()
        state.consume(line(["type":"turn_context","payload":["model":"first"]]))
        state.consume(line(["type":"event_msg","payload":["type":"token_count","info":["last_token_usage":["input_tokens":800],"model_context_window":2000]]]))
        state.consume(line(["type":"turn_context","payload":["model":"second"]]))
        XCTAssertNil(state.snapshot.capacity)
        XCTAssertTrue(state.snapshot.usageStale)
    }
    func testCompletionEventsSurviveNextTurnInSameRead() {
        var state = SessionAccumulator()
        state.consume(line(["type":"session_meta","payload":["id":"session"]]))
        state.consume(line(["type":"event_msg","payload":["type":"task_complete","turn_id":"a"]]))
        state.consume(line(["type":"event_msg","payload":["type":"task_started","turn_id":"b"]]))
        XCTAssertEqual(state.drainCompletions().map(\.key), ["session:a"])
        XCTAssertTrue(state.drainCompletions().isEmpty)
    }
    func testSameSizeRewriteWithStableMetadata() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:dir) }
        let file = dir.appendingPathComponent("log.jsonl")
        let meta = line(["type":"session_meta","payload":["id":String(repeating:"x",count:200)]])
        let first = meta + line(["type":"event_msg","payload":["type":"token_count","info":["last_token_usage":["input_tokens":800]]]])
        let second = meta + line(["type":"event_msg","payload":["type":"token_count","info":["last_token_usage":["input_tokens":100]]]])
        XCTAssertEqual(first.count,second.count)
        try first.write(to:file)
        let reader = LogReader()
        XCTAssertEqual(try reader.refresh(file).previousInput,800)
        try second.write(to:file)
        XCTAssertEqual(try reader.refresh(file).previousInput,100)
    }
    func testRecentDiscoveryIncludesResumedOlderDate() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        let older = root.appendingPathComponent("2026/10/24")
        let newer = root.appendingPathComponent("2026/10/25")
        try FileManager.default.createDirectory(at:older,withIntermediateDirectories:true)
        try FileManager.default.createDirectory(at:newer,withIntermediateDirectories:true)
        let old = older.appendingPathComponent("old.jsonl")
        let new = newer.appendingPathComponent("new.jsonl")
        try Data().write(to:old);try Data().write(to:new)
        try FileManager.default.setAttributes([.modificationDate:Date(timeIntervalSince1970:100)],ofItemAtPath:new.path)
        try FileManager.default.setAttributes([.modificationDate:Date(timeIntervalSince1970:200)],ofItemAtPath:old.path)
        XCTAssertEqual(LogReader.recentLogs(root:root,limit:1).map { $0.resolvingSymlinksInPath() },[old.resolvingSymlinksInPath()])
    }
    func testPendingReminderSurvivesRestartBaseline() {
        var ledger = CompletionLedger(pending:["old:turn"])
        XCTAssertEqual(ledger.observe([]),["old:turn"])
        ledger.acknowledge("old:turn")
        XCTAssertEqual(ledger.observe([]),[])
    }
}
