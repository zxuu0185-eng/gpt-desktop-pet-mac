import Foundation
import BailongCore
func statisticsChecks() {
    let a = UsageAccumulator()
    let line = #"{"type":"token_usage_record","timestamp":"2026-10-25T00:00:00Z","payload":{"response_id":"r1","usage":{"input_tokens":100,"cached_input_tokens":80,"output_tokens":10,"total_tokens":110}}}"#
    a.consume(Data((line + "\n" + line + "\n").utf8))
    XCTAssertEqual(a.records.count,1)
    XCTAssertEqual(a.records["r1"]?.input,100)
    XCTAssertEqual(a.records["r1"]?.cached,80)
    XCTAssertEqual(a.records["r1"]?.total,110)
    XCTAssertNil(SessionLink.url("../../bad"))
    XCTAssertEqual(SessionLink.url("01a17221-939f-7db3-996b-9dcff6605a03")?.absoluteString,"codex://threads/01a17221-939f-7db3-996b-9dcff6605a03")
}
func statisticsIndexChecks() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let folder = root.appendingPathComponent("sessions")
    let archive = root.appendingPathComponent("archived_sessions")
    try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
    try FileManager.default.createDirectory(at:archive,withIntermediateDirectories:true)
    let record = #"{"type":"token_usage_record","timestamp":"2026-10-25T00:00:00.123Z","payload":{"response_id":"a","usage":{"input_tokens":100,"cached_input_tokens":80,"output_tokens":10,"total_tokens":110}}}"#
    let model = #"{"type":"turn_context","payload":{"model":"test-model"}}"#
    let file = folder.appendingPathComponent("one.jsonl")
    try Data((model + "\n" + record).utf8).write(to:file)
    let index = StatisticsIndex()
    XCTAssertEqual(index.refresh(root:root).records.count,0)
    let h = try FileHandle(forWritingTo:file);try h.seekToEnd();try h.write(contentsOf:Data("\n".utf8));try h.close()
    var result = index.refresh(root:root)
    XCTAssertEqual(result.records.count,1);XCTAssertEqual(result.records.first?.model,"test-model")
    try Data((record + "\n").utf8).write(to:archive.appendingPathComponent("copy.jsonl"))
    XCTAssertEqual(index.refresh(root:root).records.count,1)
    try Data().write(to:file)
    result = index.refresh(root:root)
    XCTAssertEqual(result.records.count,1)
    try FileManager.default.removeItem(at:archive.appendingPathComponent("copy.jsonl"))
    XCTAssertEqual(index.refresh(root:root).records.count,0)
    let a = UsageAccumulator()
    a.consume(Data((record.replacingOccurrences(of:"\"input_tokens\":100",with:"\"input_tokens\":true") + "\n").utf8))
    XCTAssertEqual(a.skipped,1);XCTAssertEqual(a.records.count,0)
}
