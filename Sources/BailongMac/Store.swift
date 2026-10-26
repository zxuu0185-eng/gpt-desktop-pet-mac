import Foundation
import Combine
import AppKit
import UniformTypeIdentifiers
import ImageIO
import BailongCore

final class Store: ObservableObject {
    @Published var customName = UserDefaults.standard.string(forKey:"petName") ?? "白龙" {
        didSet { UserDefaults.standard.set(customName,forKey:"petName") }
    }
    var petName:String { PetPresentation.name(customName) }
    @Published var quotaExhausted = false
    @Published var preferences:PetPreferences { didSet { savePetPreferences() } }
    @Published var bubbleVisible = false
    @Published var bubblePage = "data"
    @Published var bubbleTail = "bottom"
    @Published var bubbleTailPosition:CGFloat = 0.5
    @Published var monologueText:String?
    @Published var focusID:String?
    @Published var focusNote = "未识别当前对话，可手动固定"
    @Published var pinnedID:String { didSet { UserDefaults.standard.set(pinnedID,forKey:"pinnedSession") } }
    @Published var actions:[PetAction] = []
    @Published var transientAction:String?
    @Published var actionNonce = 0
    @Published var pendingResetKey:String?
    var resetClient:QuotaClient?
    @Published var resetBusy = false
    @Published var resetMessage:String?
    var actionTimer:Timer?
    var seenCompletionAnimations = Set<String>()
    var seenPetEvents = Set<String>()
    var lowQuotaGate = LowQuotaGate()
    var queuedActions:[(String,Int,Int)] = []
    var actionPriority = 0
    var repeatsLeft = 0
    var previousGPTFront:Bool?
    var frontContextBusy = false
    var idleVariant = "idle"
    var draggingCharacter = false
    var petTimer:Timer?
    var monologueClock = MonologueClock(now:Date(),interval:900)
    var monologueEnd:Date?
    var actionEnd:Date?
    var lineIndex = 0
    var retainedSound:NSSound?
    @Published var soundMessage:String?
    var fullScreen = false
    var modalBusy = false
    var dashboardVisible = false
    var petTickCount = 0

    @Published var usage:[UsageRecord] = []
    @Published var statisticsLoading = false
    @Published var statisticsNote = "尚未读取统计"
    @Published var navigationError:String?
    private let statisticsQueue = DispatchQueue(label:"bailong.statistics",qos:.utility)
    private let statisticsIndex = StatisticsIndex()
    private var statisticsTimer:Timer?
    @Published var sessions:[SessionSnapshot] = []
    @Published var quota:QuotaSnapshot?
    @Published var quotaError:String?
    @Published var quotaLoading = false
    @Published var logError:String?
    @Published var refreshedAt:Date?
    @Published var unread:Set<String> = []
    @Published var materialDirectory:URL?
    @Published var characterScale:Double { didSet { defaults.set(characterScale,forKey:"characterScale") } }
    @Published var characterURL:URL?
    @Published var customCodex:String
    @Published var alwaysOnTop:Bool { didSet { defaults.set(alwaysOnTop,forKey:"alwaysOnTop") } }
    @Published var characterVisible:Bool { didSet { defaults.set(characterVisible,forKey:"characterVisible") } }
    private let defaults = UserDefaults.standard
    private let queue = DispatchQueue(label:"bailong.logs",qos:.utility)
    private let quotaQueue = DispatchQueue(label:"bailong.quota",qos:.utility)
    private let reader = LogReader()
    private var quotaClient:QuotaClient?
    private var timer:Timer?
    private let startedAt = Date()
    private var scan = 0
    private var urls:[URL] = []
    private var ledger:CompletionLedger
    private var titles:[String:String] = [:]
    private var cached:[URL:SessionSnapshot] = [:]
    private let dataHome:URL
    private let codexHome:URL
    init() {
        lowQuotaGate = UserDefaults.standard.data(forKey:"lowQuotaGate").flatMap { try? JSONDecoder().decode(LowQuotaGate.self,from:$0) } ?? LowQuotaGate()
        pendingResetKey = UserDefaults.standard.string(forKey:"pendingResetKey")
        preferences = UserDefaults.standard.data(forKey:"petPreferences").flatMap { try? JSONDecoder().decode(PetPreferences.self,from:$0) } ?? PetPreferences()
        pinnedID = UserDefaults.standard.string(forKey:"pinnedSession") ?? ""
        let env = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser
        codexHome = env["CODEX_HOME"].map { URL(fileURLWithPath:$0) } ?? home.appendingPathComponent(".codex")
        dataHome = home.appendingPathComponent("Library/Application Support/BailongMac",isDirectory:true)
        characterScale = min(1.6,max(0.6,UserDefaults.standard.object(forKey:"characterScale") as? Double ?? 1))
        materialDirectory = UserDefaults.standard.string(forKey:"materialDirectory").map { URL(fileURLWithPath:$0) }
        customCodex = UserDefaults.standard.string(forKey:"codexPath") ?? ""
        alwaysOnTop = UserDefaults.standard.object(forKey:"alwaysOnTop") as? Bool ?? true
        characterVisible = UserDefaults.standard.object(forKey:"characterVisible") as? Bool ?? true
        ledger = CompletionLedger(acknowledged:Set(UserDefaults.standard.stringArray(forKey:"acknowledged") ?? []),pending:Set(UserDefaults.standard.stringArray(forKey:"pendingCompletions") ?? []))
        if let path = UserDefaults.standard.string(forKey:"characterPath"),FileManager.default.fileExists(atPath:path) { characterURL = URL(fileURLWithPath:path) }
        unread = Set(ledger.observe([]))
        defaults.set(Array(unread),forKey:"pendingCompletions")
        if !UserDefaults.standard.bool(forKey:"eventAnimationDefaultsV1") {
            preferences.clickAction = "quota";preferences.completionAction = "random"
            if let data = try? JSONEncoder().encode(preferences) { UserDefaults.standard.set(data,forKey:"petPreferences") }
            UserDefaults.standard.set(true,forKey:"eventAnimationDefaultsV1")
        }
        if !defaults.bool(forKey:"soundChoicesV1") {
            preferences.clickSound = "Duck"
            if let data = try? JSONEncoder().encode(preferences) { defaults.set(data,forKey:"petPreferences") }
            defaults.set(true,forKey:"soundChoicesV1")
        }

    }
    func start() {
        startPetInteractions()
        refresh()
        refreshQuota()
        refreshStatistics()
        statisticsTimer = Timer.scheduledTimer(withTimeInterval:60,repeats:true) { [weak self] _ in self?.refreshStatistics() }
        timer = Timer.scheduledTimer(withTimeInterval:3,repeats:true) { [weak self] _ in self?.refresh() }
    }
    func stop() { actionTimer?.invalidate();resetClient?.cancel();petTimer?.invalidate();statisticsTimer?.invalidate();timer?.invalidate();timer = nil;quotaClient?.cancel() }
    func refresh() {
        queue.async { [weak self] in
            guard let self else { return }
            if self.scan % 10 == 0 || self.urls.isEmpty {
                self.urls = LogReader.recentLogs(root:self.codexHome.appendingPathComponent("sessions"))
                self.reader.retain(self.urls)
                let retained = Set(self.urls); self.cached = self.cached.filter { retained.contains($0.key) }
                self.loadTitles()
            }
            self.scan += 1
            var rows:[SessionSnapshot] = []; var failures = 0
            for url in self.urls {
                do {
                    var snapshot = try self.reader.refresh(url)
                    guard let id = snapshot.id else { continue }
                    if let title = self.titles[id],!title.isEmpty { snapshot.title = title }
                    self.cached[url] = snapshot
                    rows.append(snapshot)
                } catch { failures += 1; if let old = self.cached[url] { rows.append(old) } }
            }
            // A session may have multiple rollout files. Newest record wins without mixing IDs.
            var unique:[String:SessionSnapshot] = [:]
            for row in rows {
                guard let id = row.id else { continue }
                if let old = unique[id], (old.stateAt ?? .distantPast) > (row.stateAt ?? .distantPast) { continue }
                unique[id] = row
            }
            let petEvents = self.reader.drainPetEvents().filter { ($0.at ?? .distantPast) >= self.startedAt }
            let completionKeys = self.reader.drainCompletions().filter { !$0.isChild && ($0.at ?? .distantPast) >= self.startedAt }.map(\.key)
            let result = unique.values.sorted { ($0.stateAt ?? $0.usageAt ?? .distantPast) > ($1.stateAt ?? $1.usageAt ?? .distantPast) }
            DispatchQueue.main.async {
                self.sessions = result
                self.receivePetEvents(petEvents)
                self.refreshedAt = Date()
                self.logError = failures > 0 ? "\(failures) 份日志暂不可读" : self.urls.isEmpty ? "未找到近期 Codex 会话日志" : nil
                self.unread = Set(self.ledger.observe(completionKeys))
                self.defaults.set(Array(self.unread),forKey:"pendingCompletions")
                let freshCompletions = completionKeys.filter { self.seenCompletionAnimations.insert($0).inserted }
                if !freshCompletions.isEmpty { self.notifyCompletion() }
            }
        }
    }
    private func loadTitles() {
        let url = codexHome.appendingPathComponent("session_index.jsonl")
        guard let handle = try? FileHandle(forReadingFrom:url) else { return }
        defer { try? handle.close() }
        guard let end = try? handle.seekToEnd() else { return }
        try? handle.seek(toOffset:end > 2_000_000 ? end - 2_000_000 : 0)
        guard let data = try? handle.readToEnd() else { return }
        for row in data.split(separator:10) {
            guard let obj = try? JSONSerialization.jsonObject(with:Data(row)) as? [String:Any],let id = obj["id"] as? String,let title = obj["thread_name"] as? String else { continue }
            titles[id] = String(title.prefix(120))
        }
    }
    func acknowledge(_ key:String) {
        ledger.acknowledge(key); unread = Set(ledger.observe([]))
        defaults.set(Array(unread),forKey:"pendingCompletions")
        defaults.set(Array(ledger.acknowledged.suffix(2000)),forKey:"acknowledged")
    }
    func refreshQuota() {
        guard !quotaLoading && !resetBusy else { return }
        quotaLoading = true
        let client = QuotaClient();quotaClient = client
        let path = customCodex.trimmingCharacters(in:.whitespacesAndNewlines)
        quotaQueue.async { [weak self] in
            let result:Result<QuotaSnapshot,Error>
            do {
                guard let executable = QuotaClient.discover(custom:path.isEmpty ? nil:path) else { throw QuotaError.notFound }
                result = .success(try client.read(executable:executable))
            } catch { result = .failure(error) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.quotaLoading = false
                switch result {
                case .success(let quota): self.quota = quota;self.checkLowQuota(quota);self.quotaError = quota.windows.isEmpty ? "账户未返回可读额度周期":nil
                case .failure(let error): self.quotaError = error.localizedDescription
                }
            }
        }
    }
    func refreshStatistics() {
        guard !statisticsLoading else { return };statisticsLoading = true
        statisticsQueue.async { [weak self] in
            guard let self else { return }
            let result = self.statisticsIndex.refresh(root:self.codexHome)
            DispatchQueue.main.async {
                self.usage = result.records;self.statisticsLoading = false
                self.statisticsNote = "已去重 \(result.records.count) 次请求 · 旧日志未覆盖 \(result.legacy) 份 · 跳过 \(result.skipped) 条 · 不可读 \(result.unreadable) 份"
            }
        }
    }
    func openSession(_ id:String) {
        guard let url = SessionLink.url(id) else { navigationError = "此日志没有有效的本机会话 ID";return }
        navigationError = nil
        NSWorkspace.shared.open(url,configuration:NSWorkspace.OpenConfiguration()) { [weak self] _,error in
            if let error { DispatchQueue.main.async { self?.navigationError = error.localizedDescription } }
        }
    }
    func importSound() {
        let panel = NSOpenPanel();panel.allowedContentTypes = [.audio];panel.allowsMultipleSelection = false
        panel.title = "选择提示音（最多10 MB）";modalBusy = true
        defer { modalBusy = false }
        guard panel.runModal() == .OK,let url = panel.url else { return }
        do {
            let size = try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? Int.max
            guard size <= 10_000_000,let sound = NSSound(contentsOf:url,byReference:false),sound.duration > 0,sound.duration <= 30 else {
                soundMessage = "请选择系统支持的音频，最多10 MB、30秒。";return
            }
            let folder = dataHome.appendingPathComponent("Sounds",isDirectory:true)
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            let target = folder.appendingPathComponent(UUID().uuidString).appendingPathExtension(url.pathExtension)
            try FileManager.default.copyItem(at:url,to:target)
            preferences.customSoundPath = target.path;preferences.clickSound = "Custom"
            soundMessage = "已导入：" + url.lastPathComponent
        } catch { soundMessage = "导入失败：" + error.localizedDescription }
    }
    func removeCharacter() { characterURL = nil;materialDirectory = nil;actions = [];defaults.removeObject(forKey:"characterPath");defaults.removeObject(forKey:"materialDirectory") }
    func importMaterialDirectory() {
        let panel = NSOpenPanel();panel.title = "选择已解压的本地素材文件夹";panel.canChooseDirectories = true;panel.canChooseFiles = false
        guard panel.runModal() == .OK,let root = panel.url,FileManager.default.fileExists(atPath:root.appendingPathComponent("quality-v1/idle.webp").path) else { return }
        materialDirectory = root;defaults.set(root.path,forKey:"materialDirectory");loadActions();characterVisible = true
    }
    func animationURL(hover:Bool) -> URL? {
        guard let root = materialDirectory else { return characterURL }
        let id = displayedAction
        if id == "bowl-preview" { return Bundle.main.url(forResource:"bailong-bowl",withExtension:"gif") ?? Bundle.main.url(forResource:"bailong-bowl",withExtension:"png") }
        let path = actions.first { $0.id == id }?.path ?? "quality-v1/idle.webp"
        let url = root.appendingPathComponent(path)
        return FileManager.default.fileExists(atPath:url.path) ? url:root.appendingPathComponent("quality-v1/idle.webp")
    }
    var taskWorking:Bool { sessions.contains { !$0.isChild && $0.state == .working } }
    var displayedAction:String {
        (draggingCharacter ? "drag":nil) ?? transientAction ?? PetPresentation.baseAction(working:taskWorking,exhausted:quotaExhausted,idle:idleVariant)
    }
    func saveCodexPath() { defaults.set(customCodex,forKey:"codexPath");refreshQuota() }
    func importCharacter() {
        let panel = NSOpenPanel()
        panel.title = "导入你有权使用的角色图片"
        panel.allowedContentTypes = [.png,.jpeg,.gif,.tiff,UTType(filenameExtension:"webp")!]
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK,let url = panel.url else { return }
        statisticsQueue.async { [weak self] in
            guard let self else { return }
            do {
                let attrs = try FileManager.default.attributesOfItem(atPath:url.path)
                guard (attrs[.size] as? NSNumber)?.intValue ?? 0 < 50_000_000 else { throw CocoaError(.fileReadTooLarge) }
                guard let source = CGImageSourceCreateWithURL(url as CFURL,[kCGImageSourceShouldCache:false] as CFDictionary),
                      let props = CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [String:Any],
                      let width = props[kCGImagePropertyPixelWidth as String] as? Int,
                      let height = props[kCGImagePropertyPixelHeight as String] as? Int,
                      width > 0,height > 0,width <= 4096,height <= 4096,
                      CGImageSourceGetCount(source) <= 2000,
                      CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:512,kCGImageSourceShouldCacheImmediately:true] as CFDictionary) != nil
                else { throw CocoaError(.fileReadCorruptFile) }
                try FileManager.default.createDirectory(at:self.dataHome,withIntermediateDirectories:true)
                let target = self.dataHome.appendingPathComponent("character-\(UUID().uuidString).\(url.pathExtension)")
                try FileManager.default.copyItem(at:url,to:target)
                DispatchQueue.main.async {
                    self.materialDirectory = nil;self.defaults.removeObject(forKey:"materialDirectory")
                    self.characterURL = target;self.characterVisible = true
                    self.defaults.set(target.path,forKey:"characterPath")
                }
            } catch {
                DispatchQueue.main.async {
                    let alert = NSAlert();alert.messageText = "未能导入角色";alert.informativeText = error.localizedDescription + "（上限 50 MB、4096 × 4096 像素、2000 帧）";alert.runModal()
                }
            }
        }
    }
}
