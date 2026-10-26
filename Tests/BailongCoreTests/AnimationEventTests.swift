import Foundation
import BailongCore
func animationEventChecks() {
    var gate = LowQuotaGate()
    XCTAssertFalse(gate.observe(id:"a",remaining:11,reset:100))
    XCTAssertTrue(gate.observe(id:"a",remaining:10,reset:100))
    XCTAssertFalse(gate.observe(id:"a",remaining:9,reset:100))
    XCTAssertTrue(gate.observe(id:"a",remaining:8,reset:200))
    let saved = try! JSONEncoder().encode(gate)
    var restored = try! JSONDecoder().decode(LowQuotaGate.self,from:saved)
    XCTAssertFalse(restored.observe(id:"a",remaining:5,reset:200))
    var a = SessionAccumulator()
    let lines = [
        #"{"type":"session_meta","payload":{"id":"s"}}"#,
        #"{"timestamp":"2026-10-26T04:00:00Z","type":"event_msg","payload":{"type":"user_message","message":"private text"}}"#,
        #"{"timestamp":"2026-10-26T04:00:01Z","type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\"cmd\":\"cat /tmp/not-memory\"}","call_id":"c1"}}"#,
        #"{"timestamp":"2026-10-26T04:00:02Z","type":"response_item","payload":{"type":"function_call","name":"memory_search","arguments":"private","call_id":"c2"}}"#]
    a.consume(Data((lines.joined(separator:"\n")+"\n").utf8))
    let events = a.drainPetEvents()
    XCTAssertEqual(events.map(\.kind),[.message,.tool,.memory])
    XCTAssertEqual(events.map(\.key),["s:message:2026-10-26T04:00:00Z","s:tool:c1","s:memory:c2"])
    XCTAssertTrue(a.drainPetEvents().isEmpty)
}
