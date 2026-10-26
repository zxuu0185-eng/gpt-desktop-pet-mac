import SwiftUI
import AppKit

enum MoonPalette {
    static let ink = Color(red:0.16,green:0.13,blue:0.25)
    static let secondary = Color(red:0.37,green:0.32,blue:0.46)
    static let purple = Color(red:0.51,green:0.39,blue:0.71)
    static let line = Color(red:0.75,green:0.66,blue:0.87)
    static let pearl = Color(red:0.98,green:0.97,blue:1)
}
struct GPTKnot:View {
    var size:CGFloat = 24
    private static let mark:NSImage = {
        guard let url = Bundle.main.url(forResource:"openai-knot",withExtension:"svg"),let image=NSImage(contentsOf:url) else { return NSImage() }
        image.isTemplate = true;return image
    }()
    var body:some View {
        Image(nsImage:Self.mark).resizable().renderingMode(.template).scaledToFit()
            .foregroundStyle(LinearGradient(colors:[.white,MoonPalette.purple,MoonPalette.line],startPoint:.topLeading,endPoint:.bottomTrailing))
            .shadow(color:MoonPalette.purple.opacity(0.28),radius:1,y:1).frame(width:size,height:size)
            .accessibilityHidden(true)
    }
}
struct WingTrace:Shape {
    func path(in r:CGRect) -> Path {
        var p=Path();p.move(to:CGPoint(x:r.maxX,y:r.maxY))
        p.addQuadCurve(to:CGPoint(x:r.minX,y:r.minY),control:CGPoint(x:r.minX,y:r.maxY*0.65))
        p.addQuadCurve(to:CGPoint(x:r.width*0.35,y:r.height*0.75),control:CGPoint(x:r.width*0.4,y:r.height*0.12))
        p.addQuadCurve(to:CGPoint(x:r.width*0.67,y:r.height*0.85),control:CGPoint(x:r.width*0.6,y:r.height*0.4))
        p.addQuadCurve(to:CGPoint(x:r.maxX,y:r.maxY),control:CGPoint(x:r.width*0.9,y:r.height*0.65));p.closeSubpath();return p
    }
}
struct MoonOutline:Shape {
    var tail:String?
    var position:CGFloat = 0.5
    func path(in rect:CGRect) -> Path {
        let r=rect.insetBy(dx:10,dy:10);let c:CGFloat=22
        let x=min(max(r.minX+r.width*position,r.minX+36),r.maxX-36)
        let y=min(max(r.minY+r.height*position,r.minY+36),r.maxY-36)
        var p=Path();p.move(to:CGPoint(x:r.minX+c,y:r.minY))
        if tail == "top" { p.addLine(to:CGPoint(x:x-9,y:r.minY));p.addQuadCurve(to:CGPoint(x:x,y:rect.minY),control:CGPoint(x:x-5,y:r.minY-5));p.addLine(to:CGPoint(x:x+9,y:r.minY)) }
        p.addLine(to:CGPoint(x:r.maxX-c,y:r.minY));p.addQuadCurve(to:CGPoint(x:r.maxX,y:r.minY+c),control:CGPoint(x:r.maxX,y:r.minY))
        if tail == "right" { p.addLine(to:CGPoint(x:r.maxX,y:y-9));p.addLine(to:CGPoint(x:rect.maxX,y:y));p.addLine(to:CGPoint(x:r.maxX,y:y+9)) }
        p.addLine(to:CGPoint(x:r.maxX,y:r.maxY-c));p.addQuadCurve(to:CGPoint(x:r.maxX-c,y:r.maxY),control:CGPoint(x:r.maxX,y:r.maxY))
        if tail == "bottom" { p.addLine(to:CGPoint(x:x+9,y:r.maxY));p.addQuadCurve(to:CGPoint(x:x,y:rect.maxY),control:CGPoint(x:x+5,y:r.maxY+5));p.addLine(to:CGPoint(x:x-9,y:r.maxY)) }
        p.addLine(to:CGPoint(x:r.minX+c,y:r.maxY));p.addQuadCurve(to:CGPoint(x:r.minX,y:r.maxY-c),control:CGPoint(x:r.minX,y:r.maxY))
        if tail == "left" { p.addLine(to:CGPoint(x:r.minX,y:y+9));p.addLine(to:CGPoint(x:rect.minX,y:y));p.addLine(to:CGPoint(x:r.minX,y:y-9)) }
        p.addLine(to:CGPoint(x:r.minX,y:r.minY+c));p.addQuadCurve(to:CGPoint(x:r.minX+c,y:r.minY),control:CGPoint(x:r.minX,y:r.minY));p.closeSubpath();return p
    }
}
struct MoonSurface:ViewModifier {
    var tail:String? = nil
    var tailPosition:CGFloat = 0.5
    var ornaments = true
    func body(content:Content) -> some View {
        content.padding(12)
            .background {
                MoonOutline(tail:tail,position:tailPosition).fill(LinearGradient(colors:[.white,MoonPalette.pearl,Color(red:0.94,green:0.91,blue:0.99)],startPoint:.topLeading,endPoint:.bottomTrailing))
                    .shadow(color:MoonPalette.purple.opacity(0.18),radius:6,y:3)
            }
            .overlay {
                ZStack(alignment:.top) {
                    MoonOutline(tail:tail,position:tailPosition).stroke(MoonPalette.line,lineWidth:1.3)
                    RoundedRectangle(cornerRadius:18).stroke(.white.opacity(0.95),lineWidth:1).padding(14)
                    if ornaments {
                        HStack { WingTrace().fill(MoonPalette.line.opacity(0.4)).overlay(WingTrace().stroke(MoonPalette.purple.opacity(0.5),lineWidth:0.7)).frame(width:26,height:22);Spacer();WingTrace().fill(MoonPalette.line.opacity(0.4)).overlay(WingTrace().stroke(MoonPalette.purple.opacity(0.5),lineWidth:0.7)).scaleEffect(x:-1,y:1).frame(width:26,height:22) }.padding(.horizontal,7).padding(.top,6)
                        GPTKnot(size:18).padding(3).background(MoonPalette.pearl,in:Circle()).offset(y:0)
                    }
                }.allowsHitTesting(false).accessibilityHidden(true)
            }.foregroundStyle(MoonPalette.ink).tint(MoonPalette.purple).preferredColorScheme(.light)
    }
}
