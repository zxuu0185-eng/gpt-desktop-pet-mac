import AppKit
@main struct Check {
static func main() {
 guard let image=StatusBarIcon.load() else { fatalError("Icon failed to load") }
 let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:52,pixelsHigh:38,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:rep)
 image.draw(in:NSRect(x:0,y:0,width:52,height:38));NSGraphicsContext.restoreGraphicsState()
 var count=0
 for y in 0..<38 {for x in 0..<52 {if (rep.colorAt(x:x,y:y)?.alphaComponent ?? 0)>0.1 {count += 1}}}
 FileHandle.standardOutput.write(Data("icon logical size=\(image.size), visible pixels=\(count), template=\(image.isTemplate)\n".utf8))
 try! rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"work/status-icon-render.png"))
 precondition(count>100,"Icon is blank at menu bar size")
}
}
