import AppKit
import ImageIO
import SwiftUI

/// Decode ahead on a worker. Presentation follows the source timeline, never decode time.
private final class AnimationClip {
    var frames:[CGImage?] = []
    var ends:[Double] = []
    var total:Double { ends.last ?? 0.1 }
    var cost = 0
    var ready = false
}
final class AnimatedCharacter:NSView {
    private static let decoder = DispatchQueue(label:"bailong.animation",qos:.userInitiated)
    private static var cache:[String:AnimationClip] = [:] // main thread only
    private static var order:[String] = []
    private var clip:AnimationClip?
    private var timer:Timer?
    private var path:String?
    private var restart = -1
    private var began = ProcessInfo.processInfo.systemUptime
    var onReady:((Int) -> Void)?
    private var playbackStarted = false
    var onDoubleClick:(() -> Void)?
    private var pendingClick:DispatchWorkItem?
    var onClick:(() -> Void)?
    var onDrag:((Bool) -> Void)?
    private var downPoint:NSPoint?
    private var windowOrigin:NSPoint?
    private var dragged = false
    private var displayedIndex = -1
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        (window as? CharacterPanel)?.inputView = self
    }
    override var mouseDownCanMoveWindow:Bool { false }
    override func acceptsFirstMouse(for event:NSEvent?) -> Bool { true }
    override func accessibilityPerformPress() -> Bool { guard let onDoubleClick else { return false };onDoubleClick();return true }
    override func mouseDown(with event:NSEvent) { if event.clickCount >= 2 { pendingClick?.cancel() };downPoint = NSEvent.mouseLocation;windowOrigin = window?.frame.origin;dragged = false }
    override func mouseDragged(with event:NSEvent) {
        guard let downPoint,let windowOrigin else { return }
        let p = NSEvent.mouseLocation;let dx = p.x-downPoint.x;let dy = p.y-downPoint.y
        if !dragged && hypot(dx,dy) > 2 { dragged = true;pendingClick?.cancel();onDrag?(true) }
        if dragged { window?.setFrameOrigin(NSPoint(x:windowOrigin.x+dx,y:windowOrigin.y+dy)) }
    }
    override func mouseUp(with event:NSEvent) {
        if dragged { onDrag?(false) }
        else if event.clickCount == 2 { pendingClick?.cancel();pendingClick = nil;onDoubleClick?() }
        else if event.clickCount == 1 {
            pendingClick?.cancel()
            let item = DispatchWorkItem { [weak self] in self?.onClick?() }
            pendingClick = item;DispatchQueue.main.asyncAfter(deadline:.now()+NSEvent.doubleClickInterval,execute:item)
        }
        downPoint = nil;windowOrigin = nil;dragged = false
    }
    override init(frame:NSRect) {
        super.init(frame:frame);wantsLayer = true;layer?.contentsGravity = .resizeAspect
        setAccessibilityElement(true);setAccessibilityRole(.button);setAccessibilityLabel("角色：单击换动作，双击查看数据")
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) unsupported") }
    static func preload(_ urls:[URL]) {
        for url in urls { let loader = AnimatedCharacter(frame:.zero);loader.load(url,restart:0,sustained:url.lastPathComponent == "work02.webp") }
    }
    deinit { pendingClick?.cancel();timer?.invalidate() }
    func load(_ url:URL,restart:Int,sustained:Bool=false) {
        let key = url.path + (sustained ? "#typing":"")
        guard path != key || self.restart != restart else { return }
        path = key;self.restart = restart
        Self.order.removeAll {$0 == key};Self.order.append(key)
        playbackStarted = false
        displayedIndex = -1
        began = ProcessInfo.processInfo.systemUptime
        if let cached = Self.cache[key] { clip = cached }
        else {
            let fresh = AnimationClip();clip = fresh;Self.cache[key] = fresh
            Self.decoder.async {
                var decoded:[CGImage] = [];var ends:[Double] = [];var elapsed = 0.0
                let native = WebPFrames.decode(url) { frame,delay in
                    decoded.append(frame);elapsed += delay;ends.append(elapsed)
                }
                if !native {
                    decoded = [];ends = [];elapsed = 0
                    if let source = CGImageSourceCreateWithURL(url as CFURL,nil) {
                        for index in 0..<CGImageSourceGetCount(source) {
                            guard let image = CGImageSourceCreateThumbnailAtIndex(source,index,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:320,kCGImageSourceShouldCacheImmediately:true] as CFDictionary) else { continue }
                            let props = CGImageSourceCopyPropertiesAtIndex(source,index,nil) as? [String:Any] ?? [:]
                            let meta = props["{WebP}"] as? [String:Any] ?? props["{GIF}"] as? [String:Any] ?? [:]
                            elapsed += max(0.02,(meta["UnclampedDelayTime"] as? Double) ?? (meta["DelayTime"] as? Double) ?? 0.1)
                            decoded.append(image);ends.append(elapsed)
                        }
                    }
                }
                if sustained,decoded.count > 83 {
                    // The manifest's sustained span keeps the computer visible;
                    // replaying the whole clip repeatedly closes and reopens it.
                    let delays = ends.enumerated().map { $0.element - ($0.offset == 0 ? 0:ends[$0.offset-1]) }
                    decoded = Array(decoded[55...83]);let span = Array(delays[55...83])
                    elapsed = 0;ends = span.map { elapsed += $0;return elapsed }
                    let seam = url.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("quality-v5/work02-seam-0.webp")
                    _ = WebPFrames.decode(seam) { frame,delay in decoded.append(frame);elapsed += delay;ends.append(elapsed) }
                }
                let frames = decoded;let timing = ends
                DispatchQueue.main.async {
                    fresh.frames = frames.map { Optional($0) };fresh.ends = timing
                    fresh.cost = frames.reduce(0) {$0+$1.bytesPerRow*$1.height}
                    fresh.ready = true;Self.trimCache()
                }
            }
        }
        if timer == nil {
            let tick = Timer(timeInterval:1.0/30,repeats:true) { [weak self] _ in self?.present() }
            timer = tick;RunLoop.main.add(tick,forMode:.common)
        }
        present()
    }
    private static func trimCache() {
        var total = cache.values.reduce(0) {$0+$1.cost}
        while total > 96*1024*1024 && order.count > 1 {
            let key = order.removeFirst();total -= cache.removeValue(forKey:key)?.cost ?? 0
        }
    }
    private func present() {
        guard let window,window.isVisible,!isHidden,let clip,clip.ready,!clip.frames.isEmpty else { return }
        if !playbackStarted { playbackStarted = true;began = ProcessInfo.processInfo.systemUptime;onReady?(restart) }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            layer?.contents = clip.frames.first ?? nil
            return
        }
        let elapsed = (ProcessInfo.processInfo.systemUptime-began).truncatingRemainder(dividingBy:clip.total)
        let index = clip.ends.firstIndex(where:{$0 > elapsed}) ?? 0
        // Keep the previous image while a cold clip decodes; cached loops have no decode stalls.
        guard index != displayedIndex,index < clip.frames.count,let image = clip.frames[index] else { return }
        displayedIndex = index
        CATransaction.begin();CATransaction.setDisableActions(true);layer?.contents = image;CATransaction.commit()
    }
}
struct AnimatedCharacterView:NSViewRepresentable {
    let url:URL
    var sustained = false
    var restart:Int = 0
    var onClick:(() -> Void)? = nil
    var onDoubleClick:(() -> Void)? = nil
    var onDrag:((Bool) -> Void)? = nil
    var onReady:((Int) -> Void)? = nil
    func makeNSView(context:Context) -> AnimatedCharacter { AnimatedCharacter(frame:.zero) }
    func updateNSView(_ view:AnimatedCharacter,context:Context) { view.onClick = onClick;view.onDoubleClick = onDoubleClick;view.onDrag = onDrag;view.onReady = onReady;view.load(url,restart:restart,sustained:sustained) }
}
