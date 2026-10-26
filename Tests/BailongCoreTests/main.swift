import Foundation
var failures = 0
func XCTAssertEqual<T: Equatable>(_ a:T,_ b:T,file:StaticString=#filePath,line:UInt=#line) { if a != b { failures += 1; print("FAIL \(file):\(line): \(a) != \(b)") } }
func XCTAssertNil<T>(_ a:T?,file:StaticString=#filePath,line:UInt=#line) { if a != nil { failures += 1; print("FAIL \(file):\(line): expected nil") } }
func XCTAssertTrue(_ a:Bool,file:StaticString=#filePath,line:UInt=#line) { XCTAssertEqual(a,true,file:file,line:line) }
func XCTAssertFalse(_ a:Bool,file:StaticString=#filePath,line:UInt=#line) { XCTAssertEqual(a,false,file:file,line:line) }
func XCTAssertLessThan<T: Comparable>(_ a:T,_ b:T,file:StaticString=#filePath,line:UInt=#line) { XCTAssertTrue(a < b,file:file,line:line) }
func XCTAssertThrowsError<T>(_ f:@autoclosure () throws -> T,file:StaticString=#filePath,line:UInt=#line) { do { _ = try f();failures += 1;print("FAIL \(file):\(line): expected error") } catch {} }
let session = SessionTests()
session.testPreviousInputIsSeparateFromCumulativeAndCapacityIsNotInvented()
session.testCompactionInvalidatesOldReadoutUntilNewTokenEvent()
session.testCompletionUsesTurnIdentityAndDoesNotRetainTaskText()
try session.testPartialWriteThenTruncation()
session.testReminderBaselineDeduplicatesAndSeparatesThreads()
session.testModelChangeDoesNotKeepOldCapacity()
session.testCompletionEventsSurviveNextTurnInSameRead()
try session.testSameSizeRewriteWithStableMetadata()
try session.testRecentDiscoveryIncludesResumedOlderDate()
session.testPendingReminderSurvivesRestartBaseline()
let quota = QuotaTests()
try quota.testNamedBucketsAndMissingWindowArePreserved()
try quota.testMissingUsageIsNotZero()
try quota.testTimeoutTerminatesOwnedProcess()
quota.testCancellationBeforeStartDoesNotLaunchProcess()
statisticsChecks()
try statisticsIndexChecks()
interactionChecks()
try resetCreditChecks()
try resetRPCChecks()
resetRetryGateChecks()
animationEventChecks()
try presentationChecks()
print("22 checks, \(failures) failures")
exit(failures == 0 ? 0:1)
