import SwiftUI
import BailongCore

private let accent = DragonTheme.accent
struct Dashboard:View {
    @ObservedObject var store:Store
    @State private var tab = 0
    @State private var showChildren = false
    var body:some View {
        HStack(spacing:0) {
            VStack(alignment:.leading,spacing:28) {
                HStack(spacing:10) {
                    Image(systemName:"sparkles").font(.system(size:22)).foregroundStyle(accent)
                    VStack(alignment:.leading,spacing:3) {
                        Text(store.petName).font(.system(size:21,weight:.semibold))
                        Text("桌面伴侣").font(.system(size:11)).foregroundStyle(.secondary)
                    }
                }.padding(.top,12)
                VStack(spacing:6) {
                    navItem("会话",icon:"bubble.left.and.bubble.right",value:0)
                    navItem("额度",icon:"gauge.with.dots.needle.50percent",value:1)
                    navItem("统计",icon:"chart.bar.xaxis",value:3)
                    navItem("设置",icon:"slider.horizontal.3",value:2)
                }
                Spacer()
                VStack(alignment:.leading,spacing:8) {
                    if !store.unread.isEmpty { Label("\(store.unread.count) 个会话完成",systemImage:"checkmark.circle.fill").foregroundStyle(accent) }
                }.font(.system(size:11))
            }.padding(20).frame(width:154).frame(maxHeight:.infinity)
                .background(.ultraThinMaterial)
            Divider()
            VStack(spacing:0) {
                HStack {
                    VStack(alignment:.leading,spacing:5) {
                        SectionEyebrow(title:"BAILONG / WORKSPACE")
                        Text(tab == 0 ? "会话动态":tab == 1 ? "账户额度":tab == 3 ? "用量统计":"偏好设置")
                            .font(.system(size:27,weight:.semibold))
                    }
                    Spacer()
                    Button { store.refresh();store.refreshQuota();store.refreshStatistics() } label: { Image(systemName:"arrow.clockwise") }
                        .buttonStyle(DragonIconButton()).help("刷新数据").accessibilityLabel("刷新数据")
                }.padding(24)
            ScrollView {
                VStack(alignment:.leading,spacing:14) {
                    if tab == 0 { sessions }
                    else if tab == 1 { quotas }
                    else if tab == 3 { StatisticsView(store:store) }
                    else { settings }
                }.padding(22).frame(maxWidth:.infinity,alignment:.leading)
            }
            Divider()
            HStack {
                Circle().fill(store.logError == nil ? Color.green:Color.orange).frame(width:6,height:6)
                Text(store.logError ?? "本机日志 · 每 3 秒检查").lineLimit(1)
                Spacer()
                if let date = store.refreshedAt { Text(date,style:.time) }
            }.font(.system(size:12)).foregroundStyle(.secondary).padding(14)
        }
        }.frame(minWidth:720,minHeight:640)
        .background(DragonTheme.canvas).tint(accent)
    }
    func navItem(_ title:String,icon:String,value:Int) -> some View {
        Button { tab = value } label: {
            HStack(spacing:10) { Image(systemName:icon).frame(width:18);Text(title);Spacer() }
                .font(.system(size:13,weight:tab == value ? .semibold:.regular))
                .padding(.horizontal,12).padding(.vertical,11)
                .foregroundStyle(tab == value ? accent:Color.primary)
                .background(tab == value ? accent.opacity(0.12):Color.clear,in:RoundedRectangle(cornerRadius:10))
        }.buttonStyle(.plain)
    }
    @ViewBuilder var sessions:some View {
        if !store.unread.isEmpty {
            VStack(alignment:.leading,spacing:10) {
                Text("待确认的完成提醒").font(.system(size:17,weight:.semibold))
                ForEach(store.unread.sorted(),id: \.self) { key in
                    HStack {
                        Text(store.sessions.first { key.hasPrefix(($0.id ?? "") + ":") }?.title ?? "已完成会话")
                            .font(.system(size:12)).lineLimit(1)
                        Spacer()
                        Button("确认") { store.acknowledge(key) }
                    }
                }
            }.padding(16).background(accent.opacity(0.08),in:RoundedRectangle(cornerRadius:16))
        }
        Text("最近会话").font(.system(size:17,weight:.semibold))
        Text("上一轮输入是最近一次请求的输入量，不等同于精确的当前上下文占用。只覆盖本机可读取的近期日志。")
            .font(.system(size:12)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
        if store.sessions.isEmpty {
            ContentUnavailableView("等待本机会话",systemImage:"bubble.left.and.bubble.right",description:Text("在 Codex 中发送消息后刷新。首次读取大日志可能需要片刻。"))
        }
        Toggle("显示子任务",isOn:$showChildren).font(.system(size:12))
        if let error = store.navigationError { Text(error).foregroundStyle(.orange) }
        ForEach(store.sessions.filter { showChildren || !$0.isChild },id:\.id) { session in
            VStack(alignment:.leading,spacing:12) {
                HStack(alignment:.top) {
                    VStack(alignment:.leading,spacing:4) {
                        Text(session.title).font(.system(size:17,weight:.semibold)).lineLimit(2).textSelection(.enabled)
                        Text((session.model ?? "模型未知") + (session.isChild ? " · 子任务":"" )).font(.system(size:12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(session.state == .working ? "最后记录：工作中":session.state.label)
                        .font(.system(size:12,weight:.medium)).padding(.horizontal,9).padding(.vertical,5).background(accent.opacity(0.10),in:Capsule())
                }
                VStack(alignment:.leading,spacing:5) {
                    Text("上一轮输入 / 日志报告容量").font(.system(size:12)).foregroundStyle(.secondary)
                    Text("\(tokenText(session.previousInput)) / \(tokenText(session.capacity))")
                        .font(.system(size:24,weight:.medium,design:.rounded)).monospacedDigit()
                    Text("tokens" + (session.usageStale ? " · 压缩后等待新读数":""))
                        .font(.system(size:12)).foregroundStyle(session.usageStale ? .orange:.secondary)
                }
                Divider()
                HStack {
                    Text("累计消耗 \(tokenText(session.cumulative)) tokens")
                    Spacer()
                    if let date = session.usageAt { Text(date,style:.time) }
                }.font(.system(size:12)).foregroundStyle(.secondary)
                HStack {
                    Button("打开会话") { store.openSession(session.id ?? "") }.disabled(SessionLink.url(session.id ?? "") == nil)
                    Text("\(session.origin) · \(String((session.id ?? "").prefix(8)))").textSelection(.enabled)
                    Spacer()
                    if let key = session.completionKey,store.unread.contains(key) {
                        Button("确认完成") { store.acknowledge(key) }.buttonStyle(.borderedProminent).tint(accent)
                    }
                }.font(.system(size:12)).foregroundStyle(.secondary)
                if let date = session.stateAt { Text("最后状态事件：\(date.formatted(date:.abbreviated,time:.standard))").font(.system(size:12)).foregroundStyle(.secondary) }
            }.dragonCard()
        }
    }
    @ViewBuilder var quotas:some View {
        Text("账户额度").font(.system(size:17,weight:.semibold))
        Text("通过本机 Codex 独立读取；额度百分比不换算成 token 总量。")
            .font(.system(size:12)).foregroundStyle(.secondary)
        if store.quotaLoading { ProgressView("正在读取账户额度…").font(.system(size:12)) }
        if let error = store.quotaError { Label(error,systemImage:"exclamationmark.circle").font(.system(size:12)).foregroundStyle(.orange) }
        if let quota = store.quota {
            ForEach(quota.windows) { window in
                VStack(alignment:.leading,spacing:12) {
                    HStack { Text(window.label).font(.system(size:17,weight:.semibold));Spacer();Text("剩余 \(window.remainingPercent.formatted(.number.precision(.fractionLength(0...1))))%").font(.system(size:24,weight:.medium,design:.rounded)) }
                    ProgressView(value:window.remainingPercent,total:100).tint(accent)
                    Text(window.id).font(.system(size:12)).foregroundStyle(.secondary)
                    if let reset = window.resetsAt {
                        Text("重置：\(reset.formatted(date:.abbreviated,time:.shortened))").font(.system(size:12)).foregroundStyle(.secondary)
                        TimelineView(.periodic(from:.now,by:60)) { context in
                            Text(reset > context.date ? "距离重置约 \(Int(reset.timeIntervalSince(context.date) / 3600)) 小时 \(Int(reset.timeIntervalSince(context.date) / 60) % 60) 分钟":"已到重置时间，请刷新确认")
                                .font(.system(size:12)).foregroundStyle(.secondary)
                        }
                    }
                }.dragonCard()
            }
            Text("读数时间：\(quota.date.formatted(date:.abbreviated,time:.standard))").font(.system(size:12)).foregroundStyle(.secondary)
        }
        Button("重新读取") { store.refreshQuota() }.disabled(store.quotaLoading)
    }
    @ViewBuilder var settings:some View {
        VStack(alignment:.leading,spacing:16) {
        Label("窗口与角色",systemImage:"macwindow").font(.system(size:17,weight:.semibold))
        HStack { Text("角色名称");TextField("白龙",text:$store.customName).textFieldStyle(.roundedBorder) }
        Text("留空使用白龙，最多显示24字").font(.caption).foregroundStyle(.secondary)
        Toggle("保持窗口置顶",isOn:$store.alwaysOnTop)
        Toggle("显示角色窗口",isOn:$store.characterVisible)
        }.dragonCard()
        VStack(alignment:.leading,spacing:16) {
        Label("角色素材",systemImage:"photo.on.rectangle").font(.system(size:17,weight:.semibold))
        Text(store.characterURL == nil ? "尚未导入角色。当前版本未附带原白龙素材。":"已导入本地角色图片。")
            .font(.system(size:12)).foregroundStyle(.secondary)
        Button("导入角色图片…") { store.importCharacter() }
        Button("加载本地白龙素材文件夹…") { store.importMaterialDirectory() }
        Text("素材文件夹沿用 quality-v1 / quality-v3 目录。消息、窗口切换、额度与工具日志触发对应动作；待机间歇播放偷吃和比心。不代表实时在线状态。素材仅本机使用，应用不附带。")
            .font(.system(size:12)).foregroundStyle(.secondary)
        HStack { Text("角色大小");Slider(value:$store.characterScale,in:0.6...1.6);Text("\(Int(store.characterScale * 100))%").monospacedDigit() }

        Text("支持 PNG、JPEG、GIF、TIFF 和 WebP。请导入你有权使用的素材；支持本地 WebP 动画。")
            .font(.system(size:12)).foregroundStyle(.secondary)
        if store.characterURL != nil || store.materialDirectory != nil { Button("移除角色") { store.removeCharacter() } }
        }.dragonCard()
        VStack(alignment:.leading,spacing:16) {
        Label("Codex 连接",systemImage:"link").font(.system(size:17,weight:.semibold))
        TextField("自动发现；也可填写绝对路径",text:$store.customCodex).textFieldStyle(.roundedBorder)
        Button("保存并检测连接") { store.saveCodexPath() }
        Text("日志只读；额度连接使用独立 app-server。Codex 可能维护其自身运行状态。不会发起模型任务或导出聊天与凭据。")
            .font(.system(size:12)).foregroundStyle(.secondary)
        }.dragonCard()
    }
}
