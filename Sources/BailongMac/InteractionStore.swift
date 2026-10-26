import Foundation
import AppKit
import ApplicationServices
import BailongCore

struct PetAction:Identifiable {
    let id:String
    let name:String
    let path:String
    let duration:Double
}
extension Store {
    var focusedSession:SessionSnapshot? {
        let id = pinnedID.isEmpty ? focusID:pinnedID
        return sessions.first { $0.id == id && !$0.isChild }
    }
    func savePetPreferences() {
        if let data = try? JSONEncoder().encode(preferences) { UserDefaults.standard.set(data,forKey:"petPreferences") }
        monologueClock.reset(now:Date(),interval:max(1,preferences.intervalMinutes) * 60)
    }
    func startPetInteractions() {
        loadActions()
        monologueClock.reset(now:Date(),interval:preferences.intervalMinutes * 60)
        petTimer = Timer.scheduledTimer(withTimeInterval:1,repeats:true) { [weak self] _ in self?.petTick() }
    }
    func loadActions() {
        guard let root = materialDirectory,let data = try? Data(contentsOf:root.appendingPathComponent("素材清单.json")),let manifest = try? JSONSerialization.jsonObject(with:data) as? [String:Any] else { actions = [];return }
        var result:[PetAction] = []
        for key in ["idle","additionalIdleAnimations","variants","dragAnimation","landingAnimation","quotaAnimation","workAnimations"] {
            let rows = manifest[key] as? [[String:Any]] ?? (manifest[key] as? [String:Any]).map { [$0] } ?? []
            for row in rows {
                guard let id = row["id"] as? String,let path = row["playbackFile"] as? String,!path.hasPrefix("/"),!path.split(separator:"/").contains(".."),FileManager.default.fileExists(atPath:root.appendingPathComponent(path).path) else { continue }
                result.append(PetAction(id:id,name:String(format:"%02d",result.count+1) + " · " + (row["name"] as? String ?? "待机"),path:path,duration:max(0.1,(row["durationMs"] as? Double ?? 4500)/1000)))
            }
        }
        if Bundle.main.url(forResource:"bailong-bowl",withExtension:"png") != nil {
            result.append(PetAction(id:"bowl-preview",name:"26 · 抱盆等额度",path:"@bowl",duration:1.6))
        }
        actions = result
        AnimatedCharacter.preload(result.filter { ["idle","idle2","17","drag","landing","work02"].contains($0.id) }.map { root.appendingPathComponent($0.path) })
    }
    func playAction(_ id:String,repeatCount:Int=1,priority:Int=50) {
        guard let action = actions.first(where:{$0.id == id}) else { return }
        if actionEnd != nil && actionPriority > priority {
            // Coalesce noisy tool events; never create an unbounded backlog.
            if priority >= 70 && queuedActions.count < 8 { queuedActions.append((id,repeatCount,priority)) }
            return
        }
        if priority > actionPriority && repeatsLeft > 0,let current = transientAction,queuedActions.count < 8 {
            queuedActions.insert((current,repeatsLeft+1,actionPriority),at:0)
        }
        transientAction = id;actionPriority = priority;repeatsLeft = max(0,repeatCount-1)
        actionNonce += 1
        // Actual clip duration starts when decoded frames are ready; this watchdog
        // only releases a failed/hidden clip instead of blocking the queue forever.
        scheduleActionEnd(max(30,action.duration * 3))
    }
    func scheduleActionEnd(_ delay:Double) {
        actionTimer?.invalidate();actionEnd = Date().addingTimeInterval(delay)
        let timer = Timer(timeInterval:delay,repeats:false) { [weak self] _ in self?.finishAction() }
        actionTimer = timer;RunLoop.main.add(timer,forMode:.common)
    }
    func animationReady(_ token:Int) {
        guard token == actionNonce,let id = transientAction,let action = actions.first(where:{$0.id == id}) else { return }
        scheduleActionEnd(action.duration)
    }
    func finishAction() {
        if repeatsLeft > 0,let id = transientAction { playAction(id,repeatCount:repeatsLeft,priority:actionPriority) }
        else {
            transientAction = nil;actionEnd = nil;actionPriority = 0
            if !queuedActions.isEmpty { let next = queuedActions.removeFirst();playAction(next.0,repeatCount:next.1,priority:next.2) }
        }
    }
    func dragChanged(_ active:Bool) {
        draggingCharacter = active
        if active {
            if let current = transientAction,actionPriority >= 70,queuedActions.count < 8 {
                queuedActions.insert((current,repeatsLeft+1,actionPriority),at:0)
            }
            actionTimer?.invalidate();bubbleVisible = false;transientAction = nil;actionEnd = nil;repeatsLeft = 0;actionPriority = 0
        }
        else { playAction("landing",priority:100) }
    }
    func receivePetEvents(_ events:[PetLogEvent]) {
        let fresh = events.filter { seenPetEvents.insert($0.key).inserted }
        if seenPetEvents.count > 4000 { seenPetEvents = Set(fresh.map(\.key)) }
        if fresh.contains(where:{$0.kind == .message}) {
            playAction("04",priority:75)
        }
        if fresh.contains(where:{$0.kind == .memory}) {
            playAction("21",priority:70)
        }
    }
    func checkLowQuota(_ quota:QuotaSnapshot) {
        let wasExhausted = quotaExhausted
        quotaExhausted = PetPresentation.exhausted(quota.windows)
        if quotaExhausted && !wasExhausted {
            actionTimer?.invalidate();transientAction = nil;actionEnd = nil;actionPriority = 0;repeatsLeft = 0;queuedActions.removeAll()
        }
        var alert = false
        for w in quota.windows where w.durationMinutes == 300 {
            if lowQuotaGate.observe(id:w.id,remaining:w.remainingPercent,reset:w.resetsAt?.timeIntervalSince1970) { alert = true }
        }
        if let data = try? JSONEncoder().encode(lowQuotaGate) { UserDefaults.standard.set(data,forKey:"lowQuotaGate") }
        if alert && !quotaExhausted { playAction("14",repeatCount:5,priority:90) }
    }
    func playSound(_ name:String) {
        retainedSound?.stop()
        guard preferences.soundEnabled,name != "None" else { return }
        let source:NSSound?
        switch name {
        case "Duck","Dragon": source = Bundle.main.url(forResource:name == "Duck" ? "duck-quack":"dragon-call",withExtension:"wav").flatMap { NSSound(contentsOf:$0,byReference:false) }
        case "Custom": source = preferences.customSoundPath.flatMap { NSSound(contentsOfFile:$0,byReference:false) }
        default: source = NSSound(named:NSSound.Name(name))
        }
        guard let sound = source?.copy() as? NSSound else { return }
        sound.volume = Float(min(1,max(0,preferences.volume)));retainedSound = sound;sound.play()
    }
    var singleClickActions:[PetAction] {
        let reserved:Set<String> = [preferences.idleAction,preferences.completionAction]
        let ids = Set(PetPresentation.unassignedActions.filter { !reserved.contains($0) })
        return actions.filter { ids.contains($0.id) }
    }
    func randomIdleAction() {
        let pool = singleClickActions.map(\.id).filter { $0 != displayedAction }
        if let id = pool.randomElement() { playAction(id,priority:100) }
    }
    func showDataBubble() {
        updateFrontmostContext()
        monologueText = nil;monologueEnd = nil;bubblePage = "data"
        playSound(preferences.clickSound)
        playAction("quota",priority:100)
        bubbleVisible = true
        refreshQuota()
    }
    func notifyCompletion() {
        playAction(preferences.completionAction == "random" ? ["18","25","22"].randomElement()!:preferences.completionAction,priority:85)
        guard characterVisible,!fullScreen else { return }
        playSound(preferences.completionSound)
        // Do not interrupt settings or an open data bubble.
        if !bubbleVisible && !dashboardVisible && !preferences.bubblesMuted {
            monologueText = "完成啦！\(unread.count) 个会话等待查看"
            monologueEnd = Date().addingTimeInterval(preferences.durationSeconds)
            bubblePage = "completion";bubbleVisible = true
        }
    }
    func showMonologue(preview:Bool=false) {
        let lines = preferences.lines.map { $0.trimmingCharacters(in:.whitespacesAndNewlines) }.filter {!$0.isEmpty}
        guard !lines.isEmpty else { return }
        let text = preferences.randomLines ? lines.randomElement()!:lines[lineIndex % lines.count]
        lineIndex += 1;monologueText = text
        monologueEnd = Date().addingTimeInterval(max(1,preferences.durationSeconds))
        bubblePage = "monologue";bubbleVisible = true
    }
    func petTick() {
        let now = Date();petTickCount += 1
        if petTickCount % 2 == 0 { updateFrontmostContext() }
        if petTickCount % 18 == 0 && actionEnd == nil && !draggingCharacter {
            idleVariant = [preferences.idleAction,"idle2","17","20"].randomElement()!
        }
        if let end = monologueEnd,now >= end {
            monologueEnd = nil;monologueText = nil
            if bubblePage == "monologue" || bubblePage == "completion" { bubbleVisible = false }
        }
        if (!characterVisible || fullScreen || preferences.bubblesMuted) && (bubblePage == "monologue" || bubblePage == "completion") { bubbleVisible = false;monologueText = nil;monologueEnd = nil }
        let visible = characterVisible && !fullScreen
        if monologueClock.tick(now:now,enabled:preferences.monologueEnabled && !preferences.bubblesMuted,blocked:bubbleVisible || modalBusy || dashboardVisible || actionEnd != nil,visible:visible) { showMonologue() }
        if petTickCount % 60 == 0 { refreshQuota() }
    }
    /// Only reads window metadata; no screenshots, prompts or automatic permission request.
    func updateFrontmostContext() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        if app.bundleIdentifier == Bundle.main.bundleIdentifier { return }
        let gptFront = ["com.openai.codex","com.openai.chat"].contains(app.bundleIdentifier ?? "")
        if previousGPTFront != gptFront && (previousGPTFront != nil || gptFront) {
            playAction(gptFront ? "01":"13",priority:80)
        }
        previousGPTFront = gptFront
        guard !frontContextBusy,!draggingCharacter else { return }
        frontContextBusy = true
        let pid = app.processIdentifier
        let isCodex = app.bundleIdentifier == "com.openai.codex"
        let frames = NSScreen.screens.map(\.frame)
        let candidates = sessions
        DispatchQueue.global(qos:.utility).async { [weak self] in
            var fullScreen = false
            if let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]],let w = windows.first(where:{ ($0[kCGWindowOwnerPID as String] as? Int32) == pid && ($0[kCGWindowLayer as String] as? Int) == 0 }),let bounds = w[kCGWindowBounds as String] as? [String:Any],let rect = CGRect(dictionaryRepresentation:bounds as CFDictionary) {
                fullScreen = frames.contains { abs(rect.width-$0.width) < 3 && abs(rect.height-$0.height) < 3 }
            }
            var focus:String?
            var note = "前台不是 Codex；可手动固定会话"
            if isCodex && AXIsProcessTrusted() {
                let element = AXUIElementCreateApplication(pid)
                AXUIElementSetMessagingTimeout(element,0.1)
                var window:CFTypeRef?;var title:CFTypeRef?
                if AXUIElementCopyAttributeValue(element,kAXFocusedWindowAttribute as CFString,&window) == .success,let window,
                   AXUIElementCopyAttributeValue(window as! AXUIElement,kAXTitleAttribute as CFString,&title) == .success,let text = title as? String {
                    focus = SessionMatcher.match(title:text,candidates:candidates)
                    note = focus == nil ? "窗口标题未唯一匹配；可手动固定":"已跟随前台聊天"
                }
            } else if isCodex { note = "自动跟随需要辅助功能权限；可手动固定" }
            let resultFocus = focus;let resultScreen = fullScreen;let resultNote = note
            DispatchQueue.main.async {
                guard let self else { return };self.frontContextBusy = false
                guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }
                if self.fullScreen != resultScreen { self.fullScreen = resultScreen }
                guard self.pinnedID.isEmpty else { return }
                if self.focusID != resultFocus { self.focusID = resultFocus }
                if self.focusNote != resultNote { self.focusNote = resultNote }
            }
        }
    }

    func selectBubbleImage() {
        let panel = NSOpenPanel();panel.allowedContentTypes = [.png,.jpeg];modalBusy = true
        defer { modalBusy = false }
        guard panel.runModal() == .OK,let url = panel.url else { return }
        let size = (try? url.resourceValues(forKeys:[.fileSizeKey]).fileSize) ?? Int.max
        guard size <= 2_000_000 else { resetMessage = "配图需小于 2 MB";return }
        preferences.imagePath = url.path
    }
    func consumeReset() {
        guard ResetGate.canRequest(available:quota?.resetAvailable,pendingKey:pendingResetKey,busy:resetBusy || quotaLoading) else { return }
        let defaults = UserDefaults.standard
        let key = pendingResetKey ?? UUID().uuidString
        pendingResetKey = key
        let client = QuotaClient();resetClient = client
        defaults.set(key,forKey:"pendingResetKey")
        resetBusy = true;resetMessage = "正在使用 reset…"
        let path = customCodex
        DispatchQueue.global(qos:.utility).async { [weak self] in
            let result:Result<ResetOutcome,Error>
            do {
                guard let executable = QuotaClient.discover(custom:path.isEmpty ? nil:path) else { throw QuotaError.notFound }
                result = .success(try client.consume(executable:executable,key:key))
            } catch { result = .failure(error) }
            DispatchQueue.main.async {
                guard let self else { return };self.resetBusy = false
                switch result {
                case .success(let outcome):
                    defaults.removeObject(forKey:"pendingResetKey");self.pendingResetKey = nil
                    switch outcome {
                    case .reset,.alreadyRedeemed:self.resetMessage = "Reset 已使用，正在重新读取额度"
                    case .nothingToReset:self.resetMessage = "当前没有可重置的额度窗口"
                    case .noCredit:self.resetMessage = "没有可用 reset"
                    }
                case .failure(let error):self.resetMessage = "结果未确认：\(error.localizedDescription)。再次点击将核验同一次请求，不会换一个 reset。"
                }
                self.refreshQuota()
            }
        }
    }
}
