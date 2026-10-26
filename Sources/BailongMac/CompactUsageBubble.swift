import SwiftUI
import Charts
import BailongCore

/// Compact, light quota card above the pet. Detail pages keep the full controls.
struct CompactUsageBubble:View {
    @ObservedObject var store:Store
    let openDetails:() -> Void
    @State private var period = 0
    @State private var bucket = ""
    private let purple = MoonPalette.purple
    private let blue = Color(red:0.36,green:0.60,blue:0.73)
    private var bucketIDs:[String] { Array(Set((store.quota?.windows ?? []).map { String($0.id.split(separator:":").dropLast().joined(separator:":")) })).sorted() }
    private var activeBucket:String { bucketIDs.contains(bucket) ? bucket:bucketIDs.first(where:{$0 == "codex"}) ?? bucketIDs.first ?? "" }
    private var windows:[QuotaWindow] { (store.quota?.windows ?? []).filter { $0.id.hasPrefix(activeBucket + ":") } }
    private var filtered:[UsageRecord] {
        guard period > 0 else { return store.usage }
        let start = period == 1 ? Date().addingTimeInterval(-86400):Calendar.current.date(byAdding:.day,value:1-period,to:Calendar.current.startOfDay(for:Date()))!
        return store.usage.filter {$0.date >= start}
    }
    private struct Day:Identifiable { let id:Date;let total:Double }
    private var days:[Day] {
        Dictionary(grouping:filtered,by:{Calendar.current.startOfDay(for:$0.date)}).map { Day(id:$0.key,total:$0.value.reduce(0) {$0+Double($1.total)}) }.sorted {$0.id < $1.id}
    }
    private var today:Int64 { store.usage.filter {Calendar.current.isDateInToday($0.date)}.reduce(0) {$0+$1.total} }
    private func number(_ value:Int64) -> String {
        if value >= 1_000_000 { return String(format:"%.2fM",Double(value)/1_000_000) }
        if value >= 1000 { return String(format:"%.1fK",Double(value)/1000) }
        return value.formatted()
    }
    var body:some View {
        VStack(alignment:.leading,spacing:11) {
            HStack(spacing:10) {
                GPTKnot(size:26)
                Text("Codex").font(.system(size:16,weight:.semibold))
                Spacer()
                icon("arrow.clockwise",label:"刷新额度与统计") { store.refreshQuota();store.refreshStatistics() }
                icon("chart.bar.xaxis",label:"打开详细工作台") { store.bubbleVisible = false;openDetails() }
                icon("slider.horizontal.3",label:"陪伴设置") { store.bubblePage = "settings" }
                icon("xmark",label:"关闭气泡") { store.bubbleVisible = false }
            }
            HStack {
                Menu {
                    Picker("关注会话",selection:$store.pinnedID) {
                        Text("自动跟随前台聊天").tag("")
                        ForEach(store.sessions.filter {!$0.isChild},id:\.id) { Text($0.title).tag($0.id ?? "") }
                    }
                    if let session = store.focusedSession { Button("打开关注会话") { store.openSession(session.id ?? "") } }
                    ForEach(store.unread.sorted(),id:\.self) { key in Button("确认完成：" + (store.sessions.first { key.hasPrefix(($0.id ?? "")+":") }?.title ?? "会话")) { store.acknowledge(key) } }
                } label: {
                    HStack(spacing:6) {
                        Circle().fill(store.focusedSession?.state == .working ? purple:Color.gray).frame(width:6,height:6)
                        Text(store.focusedSession.map { $0.state == .working ? "正在处理 · " + $0.title:"等待 Codex 新消息" } ?? "等待 Codex 新消息").lineLimit(1)
                    }
                }.menuStyle(.borderlessButton).fixedSize(horizontal:false,vertical:true)
                if !store.unread.isEmpty { Text("\(store.unread.count) 个完成").font(.system(size:10,weight:.medium)).foregroundStyle(purple) }
            }.font(.system(size:13))
            HStack(alignment:.top,spacing:14) {
                VStack(alignment:.leading,spacing:11) {
                    if bucketIDs.count > 1 {
                        Picker("额度账户",selection:$bucket) { ForEach(bucketIDs,id:\.self) { Text($0).tag($0) } }.labelsHidden()
                    }
                    quotaMetric("5h 剩余",window:windows.first {$0.durationMinutes == 300},tint:purple)
                    quotaMetric("周剩余",window:windows.first {$0.durationMinutes == 10080},tint:blue)
                }.frame(width:150)
                Rectangle().fill(.black.opacity(0.07)).frame(width:1)
                VStack(alignment:.leading,spacing:9) {
                    HStack {
                        Text("Token").font(.system(size:13,weight:.semibold))
                        Spacer()
                        if (store.quota?.resetAvailable ?? 0) > 0 || store.pendingResetKey != nil {
                            Button(store.pendingResetKey != nil ? "核验 reset":"重置 · \(store.quota?.resetAvailable ?? 0)") { store.consumeReset() }
                                .disabled(store.resetBusy || store.quotaLoading).font(.system(size:11)).buttonStyle(.plain).foregroundStyle(purple)
                        }
                    }
                    HStack(spacing:4) {
                        periodButton("全部",value:0);periodButton("30天",value:30);periodButton("7天",value:7)
                    }
                    Text((period == 0 ? "全部":period == 1 ? "24h":"\(period)天") + " · " + number(filtered.reduce(0) {$0+$1.total}))
                        .font(.system(size:12,weight:.medium)).monospacedDigit()
                    if days.isEmpty {
                        Text(store.statisticsLoading ? "正在读取…":"暂无逐请求记录").font(.system(size:11)).foregroundStyle(.secondary).frame(maxWidth:.infinity,minHeight:65)
                    } else {
                        Chart(days) { day in
                            BarMark(x:.value("日期",day.id,unit:.day),y:.value("Tokens",day.total)).foregroundStyle(purple.opacity(0.75)).cornerRadius(2)
                        }.chartYAxis(.hidden).chartXAxis(.hidden).frame(height:65).accessibilityLabel("按日 Token 用量趋势")
                        HStack {
                            if let first = days.first { Text(first.id,format:.dateTime.month(.twoDigits).day(.twoDigits)) }
                            Spacer()
                            if let last = days.last { Text(last.id,format:.dateTime.month(.twoDigits).day(.twoDigits)) }
                        }.font(.system(size:9)).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth:.infinity)
            }.fixedSize(horizontal:false,vertical:true)
            HStack {
                Text("今日 Token").foregroundStyle(.secondary)
                Text(number(today)).fontWeight(.semibold).monospacedDigit()
                Spacer()
                Button("24h ›") { period = 1 }.buttonStyle(.plain).foregroundStyle(.secondary).help("查看最近24小时用量")
            }.font(.system(size:13))
            if let session = store.focusedSession {
                HStack(spacing:4) {
                    Text("上下文估算剩余")
                    if let value = ContextEstimate.remaining(input:session.previousInput,capacity:session.capacity,stale:session.usageStale) { Text(number(value)).fontWeight(.medium) }
                    else { Text("等待读数") }
                    Spacer()
                    if let date = store.quota?.date { Text(date,style:.time) }
                }.font(.system(size:10)).foregroundStyle(.secondary)
            }
            if let error = store.quotaError { Text(error).font(.system(size:10)).foregroundStyle(.red).lineLimit(2) }
            if let message = store.resetMessage { Text(message).font(.system(size:10)).foregroundStyle(.secondary).lineLimit(2) }
        }.padding(16).frame(width:360)
            .foregroundStyle(MoonPalette.ink)
            .modifier(MoonSurface())
            .preferredColorScheme(.light).tint(purple)
            .onAppear { bucket = activeBucket }
            .onChange(of:bucketIDs) { _,_ in bucket = activeBucket }
    }
    private func icon(_ symbol:String,label:String,action:@escaping ()->Void) -> some View {
        Button(action:action) { Image(systemName:symbol).font(.system(size:14)).frame(width:25,height:25) }
            .buttonStyle(.plain).help(label).accessibilityLabel(label)
    }
    private func periodButton(_ title:String,value:Int) -> some View {
        Button { period = value } label: {
            Text(title).font(.system(size:11,weight:period == value ? .semibold:.regular)).padding(.horizontal,7).padding(.vertical,4)
                .foregroundStyle(period == value ? purple:Color.secondary)
                .background(period == value ? purple.opacity(0.10):Color.clear,in:RoundedRectangle(cornerRadius:6))
        }.buttonStyle(.plain).accessibilityAddTraits(period == value ? .isSelected:[])
    }
    private func quotaMetric(_ title:String,window:QuotaWindow?,tint:Color) -> some View {
        VStack(alignment:.leading,spacing:6) {
            HStack(alignment:.firstTextBaseline) {
                Text(title).font(.system(size:13))
                Spacer()
                Text(window.map { "\(Int($0.remainingPercent))%" } ?? "—").font(.system(size:24,weight:.semibold,design:.rounded)).monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment:.leading) {
                    Capsule().fill(tint.opacity(0.14))
                    if let window { Capsule().fill(tint).frame(width:geo.size.width*window.remainingPercent/100) }
                }
            }.frame(height:7)
            if let date = window?.resetsAt {
                TimelineView(.periodic(from:.now,by:30)) { tick in
                    let mins = max(0,Int(date.timeIntervalSince(tick.date)/60))
                    Text(date <= tick.date ? "已到重置时间，请刷新":mins >= 1440 ? "\(mins/1440)天\((mins%1440)/60)时后重置":"\(mins/60)时\(mins%60)分后重置")
                }.font(.system(size:11)).foregroundStyle(.secondary)
            } else { Text(window == nil ? "暂未取得额度":"未返回重置时间").font(.system(size:11)).foregroundStyle(.secondary) }
        }
    }
}
