import AppKit

class FloatingPanel:NSPanel {
    override var canBecomeKey:Bool { true }
    override var canBecomeMain:Bool { true }
}
/// Route mouse input at the native window boundary so SwiftUI hit testing and
/// background-window dragging cannot swallow a click or start a second drag.
final class CharacterPanel:FloatingPanel {
    override init(contentRect:NSRect,styleMask:NSWindow.StyleMask,backing:NSWindow.BackingStoreType,defer flag:Bool) {
        super.init(contentRect:contentRect,styleMask:styleMask,backing:backing,defer:flag)
        collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary,.stationary]
    }
    weak var inputView:AnimatedCharacter?
    override func sendEvent(_ event:NSEvent) {
        guard let inputView else { super.sendEvent(event);return }
        switch event.type {
        case .leftMouseDown: inputView.mouseDown(with:event)
        case .leftMouseDragged: inputView.mouseDragged(with:event)
        case .leftMouseUp: inputView.mouseUp(with:event)
        default: super.sendEvent(event)
        }
    }
}
