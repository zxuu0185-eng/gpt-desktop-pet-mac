import AppKit

enum StatusBarIcon {
    // Convert the supplied white paper draft into a monochrome menu-bar mask.
    // Only its existing ink is used; no character details are redrawn.
    static func load() -> NSImage? {
        guard let url = Bundle.main.url(forResource:"BAILONG_GPT_TOPBAR_V2_SIMPLE",withExtension:"png"),
              let source = NSBitmapImageRep(data:(try? Data(contentsOf:url)) ?? Data()),
              let mask = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:source.pixelsWide,pixelsHigh:source.pixelsHigh,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0) else { return nil }
        var left=source.pixelsWide,top=source.pixelsHigh,right=0,bottom=0
        for y in 0..<source.pixelsHigh {
            for x in 0..<source.pixelsWide {
                guard let c=source.colorAt(x:x,y:y)?.usingColorSpace(.deviceRGB) else { continue }
                let luminance = 0.2126*c.redComponent + 0.7152*c.greenComponent + 0.0722*c.blueComponent
                let alpha = min(1,max(0,(0.92-luminance)/0.72))*c.alphaComponent
                mask.setColor(NSColor(deviceRed:0,green:0,blue:0,alpha:alpha),atX:x,y:y)
                if alpha > 0.5 { left=min(left,x);right=max(right,x);top=min(top,y);bottom=max(bottom,y) }
            }
        }
        guard right>left,bottom>top,let cg=mask.cgImage?.cropping(to:CGRect(x:left,y:top,width:right-left+1,height:bottom-top+1)) else { return nil }
        let height:CGFloat=19
        let image=NSImage(cgImage:cg,size:NSSize(width:height*CGFloat(cg.width)/CGFloat(cg.height),height:height))
        image.isTemplate=true
        return image
    }
}
