import AppKit
let app = NSApplication.shared
let panel = CharacterPanel(contentRect:NSRect(x:0,y:0,width:245,height:320),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
precondition(panel.collectionBehavior.contains(.canJoinAllSpaces) && panel.collectionBehavior.contains(.fullScreenAuxiliary),"Pet cannot join other desktops/fullscreen spaces")
let view = AnimatedCharacter(frame:NSRect(x:0,y:0,width:245,height:320))
panel.contentView = view;panel.inputView = view
var singles=0;var doubles=0
view.onClick = { singles += 1 };view.onDoubleClick = { doubles += 1 }
func click(_ count:Int) {
    for type:NSEvent.EventType in [.leftMouseDown,.leftMouseUp] {
        panel.sendEvent(NSEvent.mouseEvent(with:type,location:.zero,modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:panel.windowNumber,context:nil,eventNumber:count,clickCount:count,pressure:0)!)
    }
}
click(1)
RunLoop.main.run(until:Date().addingTimeInterval(NSEvent.doubleClickInterval+0.1))
precondition(singles == 1 && doubles == 0,"Single click was swallowed")
click(1);click(2)
RunLoop.main.run(until:Date().addingTimeInterval(NSEvent.doubleClickInterval+0.1))
precondition(singles == 1 && doubles == 1,"Double click also fired single action")
print("Native input checks: single fired once; double cancelled pending single")
