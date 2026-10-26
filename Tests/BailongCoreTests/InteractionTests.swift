import Foundation
import BailongCore
func interactionChecks() {
    var ledger = CompletionLedger(pending:["a:1","a:2","b:1"])
    XCTAssertEqual(ledger.observe([]).count,2)
    XCTAssertEqual(ledger.observe(["a:3"]).filter {$0.hasPrefix("a:")},["a:3"])
    ledger.acknowledge("a:3")
    XCTAssertFalse(ledger.observe(["a:1","a:2","a:3"]).contains {$0.hasPrefix("a:")})
    XCTAssertTrue(ledger.observe(["a:4"]).contains("a:4"))
    var clock = MonologueClock(now:Date(timeIntervalSince1970:0),interval:900)
    XCTAssertFalse(clock.tick(now:Date(timeIntervalSince1970:899),enabled:true,blocked:false,visible:true))
    XCTAssertFalse(clock.tick(now:Date(timeIntervalSince1970:900),enabled:true,blocked:true,visible:true))
    XCTAssertTrue(clock.tick(now:Date(timeIntervalSince1970:901),enabled:true,blocked:false,visible:true))
    XCTAssertFalse(clock.tick(now:Date(timeIntervalSince1970:2000),enabled:true,blocked:false,visible:false))
    XCTAssertFalse(clock.tick(now:Date(timeIntervalSince1970:2001),enabled:true,blocked:false,visible:true))
    XCTAssertEqual(ContextEstimate.remaining(input:100,capacity:500,stale:false),400)
    XCTAssertNil(ContextEstimate.remaining(input:100,capacity:500,stale:true))
    XCTAssertNil(ContextEstimate.remaining(input:600,capacity:500,stale:false))
}
func resetCreditChecks() throws {
    let q = try QuotaSnapshot.decode(Data(#"{"rateLimitResetCredits":{"availableCount":2,"credits":[]}}"#.utf8))
    XCTAssertEqual(q.resetAvailable,2)
    XCTAssertNil(try QuotaSnapshot.decode(Data("{}".utf8)).resetAvailable)
    XCTAssertEqual(try QuotaSnapshot.decode(Data(#"{"rateLimitResetCredits":{"availableCount":0}}"#.utf8)).resetAvailable,0)
    XCTAssertEqual(try ResetOutcome.decode(["outcome":"alreadyRedeemed"]),.alreadyRedeemed)
    XCTAssertThrowsError(try ResetOutcome.decode(["outcome":"unexpected"]))
}
func resetRPCChecks() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
    defer { try? FileManager.default.removeItem(at:root) }
    let script = root.appendingPathComponent("server")
    let request = root.appendingPathComponent("request.json")
    let text = """
    #!/bin/sh
    read -r init
    printf '%s\\n' '{"id":1,"result":{}}'
    read -r initialized
    read -r request
    printf '%s' "$request" > '\(request.path)'
    printf '%s\\n' '{"id":2,"result":{"outcome":"reset"}}'
    """
    try Data(text.utf8).write(to:script)
    try FileManager.default.setAttributes([.posixPermissions:0o700],ofItemAtPath:script.path)
    let key = UUID().uuidString
    XCTAssertEqual(try QuotaClient().consume(executable:script,key:key),.reset)
    let obj = try JSONSerialization.jsonObject(with:Data(contentsOf:request)) as! [String:Any]
    XCTAssertEqual(obj["method"] as? String,"account/rateLimitResetCredit/consume")
    XCTAssertEqual((obj["params"] as? [String:Any])?["idempotencyKey"] as? String,key)
    XCTAssertEqual(try QuotaClient().consume(executable:script,key:key),.reset)
    let second = try JSONSerialization.jsonObject(with:Data(contentsOf:request)) as! [String:Any]
    XCTAssertEqual((second["params"] as? [String:Any])?["idempotencyKey"] as? String,key)
    var a = SessionSnapshot();a.id = "a";a.title = "same"
    var b = SessionSnapshot();b.id = "b";b.title = "same"
    XCTAssertEqual(SessionMatcher.match(title:"same",candidates:[a]),"a")
    XCTAssertNil(SessionMatcher.match(title:"same",candidates:[a,b]))
    XCTAssertNil(SessionMatcher.match(title:"other",candidates:[a]))
}
func resetRetryGateChecks() {
    XCTAssertTrue(ResetGate.canRequest(available:0,pendingKey:"saved",busy:false))
    XCTAssertTrue(ResetGate.canRequest(available:nil,pendingKey:"saved",busy:false))
    XCTAssertFalse(ResetGate.canRequest(available:0,pendingKey:nil,busy:false))
    XCTAssertFalse(ResetGate.canRequest(available:2,pendingKey:nil,busy:true))
}
