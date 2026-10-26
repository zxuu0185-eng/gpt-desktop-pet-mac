import AppKit
import SwiftUI
import BailongCore

struct CompanionView:View {
    @ObservedObject var store:Store
    let open:() -> Void
    @State private var hover = false
    var body:some View {
        VStack(spacing:8) {
            if let url = store.animationURL(hover:hover) { AnimatedCharacterView(url:url,sustained:store.displayedAction == "work02",restart:store.actionNonce,onClick:{ store.randomIdleAction() },onDoubleClick:{ store.showDataBubble() },onDrag:{ store.dragChanged($0) },onReady:{ store.animationReady($0) }).frame(width:210 * store.characterScale,height:235 * store.characterScale).onHover { hover = $0 } }
            else {
                VStack(spacing:12) {
                    Image(systemName:"sparkles").font(.system(size:40,weight:.light)).foregroundStyle(.white)
                    Text("未导入角色").font(.system(size:12)).foregroundStyle(.white.opacity(0.85))
                }.frame(width:164,height:156).background(.indigo.gradient,in:RoundedRectangle(cornerRadius:40))
            }
            HStack {
                HStack(spacing:8) {
                    GPTKnot(size:20)
                    Text(store.unread.isEmpty ? "\(store.petName) · 双击查看数据":"\(store.unread.count) 个任务完成")
                    Image(systemName:"chevron.right").font(.system(size:12))
                }.font(.system(size:12,weight:.medium)).lineLimit(1).minimumScaleFactor(0.8).padding(.horizontal,14).padding(.vertical,9)
                    .background(LinearGradient(colors:[.white,MoonPalette.pearl],startPoint:.top,endPoint:.bottom),in:Capsule())
                    .overlay(Capsule().stroke(MoonPalette.line,lineWidth:1.2))
                    .overlay(Capsule().stroke(.white,lineWidth:0.8).padding(3))
                    .shadow(color:MoonPalette.purple.opacity(0.16),radius:3,y:2)
                    .foregroundStyle(MoonPalette.ink).preferredColorScheme(.light)
            }.contentShape(Capsule())
                .gesture(TapGesture(count:2).onEnded { store.showDataBubble() }.exclusively(before:TapGesture().onEnded { store.randomIdleAction() }))
                .accessibilityElement(children:.combine).accessibilityAddTraits(.isButton)
                .accessibilityAction { store.showDataBubble() }
        }.padding(15)
    }
}
