import SwiftUI
import Charts
import AppKit
import UniformTypeIdentifiers
import BailongCore

struct StatisticsView:View {
    @ObservedObject var store:Store
    @State private var period = 7
    @State private var model = "全部模型"
    private var calendar:Calendar { .current }
    private var rows:[UsageRecord] {
        let start = calendar.startOfDay(for:Date())
        let lower = period == 0 ? Date.distantPast:calendar.date(byAdding:.day,value:period == -1 ? -1:1-period,to:start)!
        let upper = period == -1 ? start:Date()
        return store.usage.filter { $0.date >= lower && $0.date < upper && (model == "全部模型" || $0.model == model) }
    }
    private struct Bucket:Identifiable { var id:Date;var value:Double }
    private var buckets:[Bucket] {
        let component:Calendar.Component = period == 1 || period == -1 ? .hour:.day
        let grouped = Dictionary(grouping:rows) { calendar.dateInterval(of:component,for:$0.date)!.start }
        return grouped.map { Bucket(id:$0.key,value:$0.value.reduce(0) {$0 + Double($1.total)}) }.sorted {$0.id < $1.id}
    }
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack { Text("用量统计").font(.system(size:17,weight:.semibold));Spacer();Button("刷新") { store.refreshStatistics() }.disabled(store.statisticsLoading) }
            Picker("时间",selection:$period) { Text("今日").tag(1);Text("昨日").tag(-1);Text("7天").tag(7);Text("30天").tag(30);Text("累计").tag(0) }.pickerStyle(.segmented)
            Picker("模型",selection:$model) { Text("全部模型").tag("全部模型");ForEach(Set(store.usage.map(\.model)).sorted(),id:\.self) { Text($0).tag($0) } }
            if store.statisticsLoading { ProgressView("正在后台索引本机日志…") }
            Text(rows.reduce(Int64(0)) {$0 + $1.total}.formatted()).font(.system(size:32,weight:.medium,design:.rounded)).monospacedDigit()
            Text("tokens · \(rows.count) 次请求").foregroundStyle(.secondary)
            Grid(alignment:.leading,horizontalSpacing:24,verticalSpacing:8) {
                GridRow { Text("输入");Text(rows.reduce(Int64(0)) {$0 + $1.input}.formatted()) }
                GridRow { Text("其中缓存输入");Text(rows.reduce(Int64(0)) {$0 + $1.cached}.formatted()) }
                GridRow { Text("输出");Text(rows.reduce(Int64(0)) {$0 + $1.output}.formatted()) }
            }.font(.system(size:13)).monospacedDigit()
            Chart(buckets) { b in BarMark(x:.value("时间",b.id),y:.value("tokens",b.value)).foregroundStyle(DragonTheme.accent) }.frame(height:180)
            Text(period == 1 || period == -1 ? "按本地时间每小时归桶":"按本地时间每日归桶").font(.system(size:12)).foregroundStyle(.secondary)
            Text("输入包含缓存输入，输出包含推理输出；不重复相加。统计取自有请求 ID 和时间的逐请求用量记录，旧版累计日志不计入。不是账单或额度换算。")
                .font(.system(size:12)).foregroundStyle(.secondary)
            Button("导出当前统计报告…") { exportReport() }.disabled(store.statisticsLoading)
            Text(store.statisticsNote).font(.system(size:12)).foregroundStyle(.secondary)
        }.dragonCard()
    }
    private func exportReport() {
        let panel = NSSavePanel();panel.nameFieldStringValue = "白龙用量报告.md";panel.allowedContentTypes = [UTType(filenameExtension:"md") ?? .plainText]
        guard panel.runModal() == .OK,let url = panel.url else { return }
        let labels = [1:"今日",-1:"昨日",7:"最近7天",30:"最近30天",0:"累计"]
        var report = "# 白龙本机用量报告\n\n生成时间：\(Date().formatted())\n\n范围：\(labels[period] ?? "未知") · \(model)\n\n请求数：\(rows.count)\n\n| 指标 | tokens |\n| --- | ---: |\n"
        for (name,value) in [("输入",rows.reduce(Int64(0)) {$0 + $1.input}),("其中缓存输入",rows.reduce(Int64(0)) {$0 + $1.cached}),("输出",rows.reduce(Int64(0)) {$0 + $1.output}),("合计",rows.reduce(Int64(0)) {$0 + $1.total})] { report += "| \(name) | \(value) |\n" }
        report += "\n输入已包含缓存；输出已包含推理。不重复相加。仅计入本机有请求 ID 与时间的逐请求记录，按 ID 去重；旧版累计日志未覆盖。非账单。\n\n\(store.statisticsNote)\n\n| 时间桶（本地时间） | tokens |\n| --- | ---: |\n"
        for b in buckets { report += "| \(b.id.formatted()) | \(Int64(b.value)) |\n" }
        do { try report.write(to:url,atomically:true,encoding:.utf8) }
        catch { let alert = NSAlert();alert.messageText = "导出失败";alert.informativeText = error.localizedDescription;alert.runModal() }
    }

}
