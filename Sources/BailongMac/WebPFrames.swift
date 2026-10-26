import Foundation
import CoreGraphics
import ImageIO

/// ANMF demux avoids ImageIO repeatedly reconstructing every earlier WebP frame.
/// Pixel decoding still uses the system codec; composition follows WebP blend/dispose flags.
enum WebPFrames {
    static func decode(_ url:URL,maxPixels:Int=320,emit:(CGImage,Double)->Void) -> Bool {
        guard let data = try? Data(contentsOf:url),data.count >= 30,
              String(data:data[0..<4],encoding:.ascii) == "RIFF",
              String(data:data[8..<12],encoding:.ascii) == "WEBP" else { return false }
        let bytes = [UInt8](data)
        func uint(_ start:Int,_ count:Int) -> Int {
            (0..<count).reduce(0) { $0 | Int(bytes[start+$1]) << ($1*8) }
        }
        var offset = 12;var width = 0;var height = 0
        var chunks:[(Int,Int)] = []
        while offset+8 <= bytes.count {
            let length = uint(offset+4,4);let start = offset+8
            guard length <= bytes.count-start else { return false }
            let tag = String(bytes:bytes[offset..<offset+4],encoding:.ascii)
            if tag == "VP8X",length >= 10 { width = uint(start+4,3)+1;height = uint(start+7,3)+1 }
            if tag == "ANMF",length >= 16 { chunks.append((start,length)) }
            offset = start+length+(length&1)
        }
        guard width > 0,height > 0,width <= 4096,height <= 4096,!chunks.isEmpty,chunks.count <= 1000 else { return false }
        let scale = min(1,Double(maxPixels)/Double(max(width,height)))
        guard let canvas = CGContext(data:nil,width:max(1,Int(Double(width)*scale)),height:max(1,Int(Double(height)*scale)),bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        canvas.scaleBy(x:scale,y:scale)
        func little(_ value:Int,_ count:Int) -> [UInt8] { (0..<count).map { UInt8((value >> ($0*8)) & 255) } }
        for (start,length) in chunks {
            let x = uint(start,3)*2;let y = uint(start+3,3)*2
            let w = uint(start+6,3)+1;let h = uint(start+9,3)+1
            guard x+w <= width,y+h <= height else { return false }
            let duration = max(0.02,Double(uint(start+12,3))/1000)
            let flags = bytes[start+15]
            // VP8X alpha capability permits both ALPH+VP8 and VP8L subframes.
            let extended:[UInt8] = Array("VP8X".utf8)+little(10,4)+[16,0,0,0]+little(w-1,3)+little(h-1,3)
            let payload = extended+Array(bytes[(start+16)..<(start+length)])
            let single = Data(Array("RIFF".utf8)+little(payload.count+4,4)+Array("WEBP".utf8)+payload)
            let rect = CGRect(x:x,y:height-y-h,width:w,height:h)
            let image:CGImage? = autoreleasepool {
                guard let source = CGImageSourceCreateWithData(single as CFData,nil) else { return nil }
                return CGImageSourceCreateImageAtIndex(source,0,[kCGImageSourceShouldCacheImmediately:true] as CFDictionary)
            }
            guard let image else { return false }
            if flags & 2 != 0 { canvas.clear(rect) }
            canvas.draw(image,in:rect)
            guard let frame = canvas.makeImage() else { return false }
            emit(frame,duration)
            if flags & 1 != 0 { canvas.clear(rect) }
        }
        return true
    }
}
