import Foundation
import CoreGraphics

public enum PetPresentation {
    // IDs differ from the 1-based preview numbers: 05,06,07,16,17,21,23,24,25.
    public static let unassignedActions = ["05","08","09","24","26","work01","work03","work04","work05"]
    public static func name(_ value:String) -> String {
        let clean = value.trimmingCharacters(in:.whitespacesAndNewlines)
        return clean.isEmpty ? "白龙":String(clean.prefix(24))
    }
    public static func exhausted(_ windows:[QuotaWindow]) -> Bool {
        windows.contains { ($0.durationMinutes == 300 || $0.durationMinutes == 10080) && $0.remainingPercent <= 0 }
    }
    public static func baseAction(working:Bool,exhausted:Bool,idle:String) -> String {
        exhausted ? "bowl-preview":working ? "work02":idle
    }
    public static func randomPool(available:[String],assigned:Set<String>,current:String?=nil) -> [String] {
        let idle = ["idle","idle2","17","20"]
        return available.filter { $0 != current && !idle.contains($0) && !assigned.contains($0) && $0 != "bowl-preview" }
    }
    public static func bubbleFrame(pet:CGRect,size:CGSize,screen:CGRect,gap:CGFloat=16) -> CGRect? {
        let x = min(max(pet.midX-size.width/2,screen.minX),screen.maxX-size.width)
        let y = min(max(pet.midY-size.height/2,screen.minY),screen.maxY-size.height)
        let candidates = [CGRect(x:x,y:pet.maxY+gap,width:size.width,height:size.height),
                          CGRect(x:x,y:pet.minY-gap-size.height,width:size.width,height:size.height),
                          CGRect(x:pet.minX-gap-size.width,y:y,width:size.width,height:size.height),
                          CGRect(x:pet.maxX+gap,y:y,width:size.width,height:size.height)]
        return candidates.first { screen.contains($0) && !$0.intersects(pet) }
    }
}
