import Foundation
import CoreGraphics
import BailongCore
func presentationChecks() throws {
    XCTAssertEqual(PetPresentation.name(" \n "),"白龙")
    XCTAssertEqual(PetPresentation.name("  小白  "),"小白")
    XCTAssertEqual(PetPresentation.name(String(repeating:"龙",count:30)).count,24)
    let screen=CGRect(x:0,y:0,width:1280,height:800)
    for pet in [CGRect(x:1000,y:40,width:245,height:320),CGRect(x:500,y:430,width:245,height:320),CGRect(x:0,y:200,width:245,height:320)] {
        let frame=PetPresentation.bubbleFrame(pet:pet,size:CGSize(width:460,height:340),screen:screen)
        XCTAssertTrue(frame != nil)
        if let frame { XCTAssertFalse(frame.intersects(pet));XCTAssertTrue(screen.contains(frame)) }
    }
    XCTAssertEqual(PetPresentation.randomPool(available:["idle","idle2","17","20","04","drag","bowl-preview","05"],assigned:["04","drag"]),["05"])
    let q=try QuotaSnapshot.decode(Data(#"{"rateLimits":{"primary":{"usedPercent":100,"windowDurationMins":300}}}"#.utf8))
    XCTAssertTrue(PetPresentation.exhausted(q.windows))
    XCTAssertFalse(PetPresentation.exhausted([]))
    XCTAssertEqual(PetPresentation.randomPool(available:["idle","idle2","17"],assigned:[],current:"idle"),[])
    XCTAssertEqual(PetPresentation.randomPool(available:["idle","quota","drag"],assigned:["drag"]),["quota"])
    let old = try JSONEncoder().encode(PetPreferences())
    XCTAssertEqual(try JSONDecoder().decode(PetPreferences.self,from:old).clickSound,"Pop")
    XCTAssertEqual(PetPresentation.baseAction(working:true,exhausted:false,idle:"idle"),"work02")
    XCTAssertEqual(PetPresentation.baseAction(working:false,exhausted:false,idle:"idle2"),"idle2")
    XCTAssertEqual(PetPresentation.baseAction(working:true,exhausted:true,idle:"idle"),"bowl-preview")
    XCTAssertEqual(PetPresentation.unassignedActions,["05","08","09","24","26","work01","work03","work04","work05"])
}
