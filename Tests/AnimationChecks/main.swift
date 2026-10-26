import Foundation
import CoreGraphics
import ImageIO
var failures = 0
func pixels(_ image:CGImage,_ w:Int,_ h:Int)->[UInt8] {
 let ctx=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
 ctx.draw(image,in:CGRect(x:0,y:0,width:w,height:h))
 return Array(UnsafeBufferPointer(start:ctx.data!.assumingMemoryBound(to:UInt8.self),count:w*h*4))
}
let root=URL(fileURLWithPath:CommandLine.arguments[1])
for path in ["quality-v1/idle.webp","quality-v1/drag.webp","quality-v1/landing.webp","quality-v2/18.webp"] {
 let url=root.appendingPathComponent(path)
 guard let source=CGImageSourceCreateWithURL(url as CFURL,nil) else { failures+=1;continue }
 var frames:[CGImage]=[];var duration=0.0;let start=Date()
 let ok=WebPFrames.decode(url) { image,delay in frames.append(image);duration+=delay }
 guard ok,frames.count == CGImageSourceGetCount(source),duration>0 else { failures+=1;continue }
 for index in [0,frames.count/2,frames.count-1] {
  let image=frames[index]
  guard let reference=CGImageSourceCreateImageAtIndex(source,index,nil) else { failures+=1;continue }
  let a=pixels(image,image.width,image.height);let b=pixels(reference,image.width,image.height)
  let error=zip(a,b).reduce(0.0) {$0+Double(abs(Int($1.0)-Int($1.1)))}/Double(a.count)
  if error>0.5 { failures+=1;print("FAIL",path,index,error) }
 }
 print(path,frames.count,"frames, elapsed",Date().timeIntervalSince(start))
}
print("Animation checks:",failures,"failures")
exit(failures == 0 ? 0:1)
