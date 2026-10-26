import SwiftUI
import AppKit
import BailongCore

struct BubbleView:View {
    @ObservedObject var store:Store
    let openDetails:() -> Void
    var body:some View {
        Group {
            if store.bubblePage == "data" { CompactUsageBubble(store:store,openDetails:openDetails) }
            else if store.bubblePage == "monologue" || store.bubblePage == "completion" { dialogueBody }
            else { detailsBody }
        }
    }
    var dialogueBody:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack(spacing:8) {
                Button { store.monologueEnd = nil;store.bubblePage = "data" } label: { Image(systemName:"chevron.left") }.buttonStyle(DragonIconButton()).accessibilityLabel("返回数据")
                GPTKnot(size:24)
                Text(store.petName).font(.system(size:15,weight:.semibold)).lineLimit(1)
                Spacer()
                Button { store.bubbleVisible = false } label: { Image(systemName:"xmark") }.buttonStyle(DragonIconButton()).accessibilityLabel("关闭气泡")
            }
            Rectangle().fill(MoonPalette.line.opacity(0.5)).frame(height:0.6)
            if let path = store.preferences.imagePath,let image = NSImage(contentsOfFile:path) { Image(nsImage:image).resizable().scaledToFit().frame(maxHeight:120).clipShape(RoundedRectangle(cornerRadius:10)) }
            ScrollView { Text(store.monologueText ?? "").font(.system(size:17,weight:.medium)).lineSpacing(5).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) }.frame(maxHeight:220).fixedSize(horizontal:false,vertical:true)
            if store.bubblePage == "completion" { Button("查看完成会话") { store.monologueEnd = nil;store.bubblePage = "data" }.buttonStyle(.plain).font(.system(size:12,weight:.medium)) }
        }.padding(18).frame(width:320)
            .modifier(MoonSurface(tail:store.bubbleTail,tailPosition:store.bubbleTailPosition))
    }
    var detailsBody:some View {
        VStack(spacing:0) {
            HStack(spacing:10) {
                if store.bubblePage != "data" {
                    Button { store.monologueEnd = nil;store.monologueText = nil;store.bubblePage = store.bubblePage == "actions" ? "settings":"data" } label: { Image(systemName:"chevron.left") }
                        .buttonStyle(DragonIconButton()).accessibilityLabel("返回上一页")
                } else {
                    Image(systemName:"sparkles").font(.system(size:20)).foregroundStyle(DragonTheme.accent)
                }
                VStack(alignment:.leading,spacing:3) {
                    Text(store.bubblePage == "settings" ? "陪伴设置":store.bubblePage == "actions" ? "动作收藏":store.petName)
                        .font(.system(size:17,weight:.semibold))
                    Text(store.bubblePage == "data" ? "此刻的工作状态":store.bubblePage == "settings" ? "":store.bubblePage == "actions" ? "为每个时刻挑一个动作":"有句话想对你说")
                        .font(.system(size:11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { store.bubbleVisible = false } label: { Image(systemName:"xmark") }
                    .buttonStyle(DragonIconButton()).help("关闭气泡").accessibilityLabel("关闭气泡")
            }.padding(20)
            Divider().opacity(0.5)
            ScrollView {
                VStack(alignment:.leading,spacing:16) {
                    if store.bubblePage == "settings" { settings }
                    else if store.bubblePage == "actions" { animationSettings }
                    else if store.bubblePage == "monologue" || store.bubblePage == "completion" {
                        if let path = store.preferences.imagePath,let image = NSImage(contentsOfFile:path) { Image(nsImage:image).resizable().scaledToFit().frame(maxHeight:140).clipShape(RoundedRectangle(cornerRadius:12)) }
                        Text(store.monologueText ?? "").font(.system(size:21,weight:.medium)).lineSpacing(6).fixedSize(horizontal:false,vertical:true)
                        if store.bubblePage == "completion" { Button("查看完成会话") { store.monologueEnd = nil;store.bubblePage = "data" } }
                    } else { EmptyView() }
                }.padding(20).frame(maxWidth:.infinity,alignment:.leading)
            }
            if store.bubblePage == "data" {
                Divider().opacity(0.5)
                HStack {
                    Button { store.bubblePage = "settings" } label: { Label("陪伴设置",systemImage:"slider.horizontal.3") }
                    Spacer()
                    Button { store.bubbleVisible = false;openDetails() } label: { Label("工作台",systemImage:"arrow.up.right.square") }
                }.buttonStyle(.plain).font(.system(size:12,weight:.medium)).foregroundStyle(DragonTheme.accent).padding(18)
            }
        }.frame(width:390,height:570)
            .background(MoonPalette.pearl).modifier(MoonSurface(ornaments:false))
    }
    var settings:some View {
        VStack(alignment:.leading,spacing:12) {
            VStack(alignment:.leading,spacing:14) {
            Label("自言自语",systemImage:"quote.bubble").font(.headline)
            Toggle("定时说一句",isOn:$store.preferences.monologueEnabled)
            Toggle("暂停自动气泡",isOn:$store.preferences.bubblesMuted)
            Stepper("间隔：\(Int(store.preferences.intervalMinutes)) 分钟",value:$store.preferences.intervalMinutes,in:1...180,step:1)
            Stepper("显示：\(Int(store.preferences.durationSeconds)) 秒",value:$store.preferences.durationSeconds,in:1...30,step:1)
            Toggle("随机台词（关闭则顺序播放）",isOn:$store.preferences.randomLines)
            Text("每行一句，可自行修改").font(.caption).foregroundStyle(.secondary)
            TextEditor(text:Binding(get:{store.preferences.lines.joined(separator:"\n")},set:{store.preferences.lines = $0.components(separatedBy:"\n")})).font(.system(size:13)).frame(height:100).scrollContentBackground(.hidden).padding(8).background(DragonTheme.canvas,in:RoundedRectangle(cornerRadius:10))
            HStack { Button("选择气泡配图…") { store.selectBubbleImage() };Button("移除配图") { store.preferences.imagePath = nil } }
            if let path = store.preferences.imagePath { Text(URL(fileURLWithPath:path).lastPathComponent).font(.caption).foregroundStyle(.secondary) }
            Button("立即说一句（预览）") { store.showMonologue(preview:true) }
            Text("隐藏或全屏时暂停，恢复后重新计时；数据气泡、设置及完成动作期间推迟。空台词不播放。").font(.caption).foregroundStyle(.secondary)
            }.dragonCard()
            VStack(alignment:.leading,spacing:14) {
            Label("声音",systemImage:"speaker.wave.2").font(.headline)
            Toggle("启用双击与完成声音",isOn:$store.preferences.soundEnabled)
            HStack { Text("音量");Slider(value:$store.preferences.volume,in:0...1) }
            soundPicker("双击",selection:$store.preferences.clickSound)
            soundPicker("完成",selection:$store.preferences.completionSound)
            HStack { Button("导入其他声音…") { store.importSound() };Button("试听双击音") { store.playSound(store.preferences.clickSound) };Button("试听完成音") { store.playSound(store.preferences.completionSound) } }
            Text("单击换动作保持静音。自定义音频支持系统可读格式，最多10 MB、30秒。").font(.caption).foregroundStyle(.secondary)
            if let message = store.soundMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
            }.dragonCard()
            Button { store.bubblePage = "actions" } label: { HStack { Label("动画配置与预览",systemImage:"sparkles.tv");Spacer();Image(systemName:"chevron.right") }.padding(16).background(DragonTheme.surface,in:RoundedRectangle(cornerRadius:14)) }.buttonStyle(.plain)
        }.font(.system(size:13))
    }
    func soundPicker(_ title:String,selection:Binding<String>) -> some View {
        Picker(title,selection:selection) {
            Text("静音").tag("None");Text("小黄鸭").tag("Duck");Text("龙叫").tag("Dragon")
            if store.preferences.customSoundPath != nil { Text("自定义音频").tag("Custom") }
            ForEach(["Pop","Glass","Ping","Purr","Tink","Hero"],id:\.self) { Text($0).tag($0) }
        }
    }
    var animationSettings:some View {
        VStack(alignment:.leading,spacing:12) {
            if store.actions.isEmpty { Text("请先在详细面板设置中加载本地素材文件夹。").foregroundStyle(.secondary) }
            actionPicker("待机",selection:$store.preferences.idleAction)
            Text("工作：22 · 敲电脑，持续到任务完成").font(.system(size:12)).foregroundStyle(.secondary)
            Text("单击：仅未分配动作，不含待机").font(.system(size:12)).foregroundStyle(.secondary)
            Text(store.singleClickActions.isEmpty ? "当前没有未分配动作":store.singleClickActions.map(\.name).joined(separator:"、")).font(.caption).foregroundStyle(.secondary)
            actionPicker("完成提醒",selection:$store.preferences.completionAction)
            Text("完成动作播放一次后回到待机或工作，未查看提醒不循环播放动作。").font(.caption).foregroundStyle(.secondary)
            Divider();Text("全部 \(store.actions.count) 段动作 · 点选预览").font(.headline)
            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:10) {
                ForEach(store.actions) { action in
                    Button { store.playAction(action.id) } label: {
                        HStack(spacing:8) {
                            Image(systemName:"play.circle.fill").font(.system(size:20)).foregroundStyle(DragonTheme.accent)
                            Text(action.name).lineLimit(2).multilineTextAlignment(.leading)
                            Spacer(minLength:0)
                        }.frame(maxWidth:.infinity,minHeight:44).padding(10)
                            .background(DragonTheme.surface,in:RoundedRectangle(cornerRadius:12))
                    }.buttonStyle(.plain).help("预览：" + action.name)
                }
            }
        }.font(.system(size:13))
    }
    func actionPicker(_ title:String,selection:Binding<String>) -> some View {
        Picker(title,selection:selection) {
            if title == "完成提醒" { Text("随机 · 10 / 11 / 12").tag("random") }
            ForEach(store.actions) { action in Text(action.name).tag(action.id) } }
    }
}
