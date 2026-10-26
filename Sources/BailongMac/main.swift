import AppKit
import SwiftUI
import Combine
import BailongCore

final class AppDelegate:NSObject,NSApplicationDelegate,NSWindowDelegate {
    let store = Store()
    private var panel:FloatingPanel!
    private var character:FloatingPanel!
    private var status:NSStatusItem!
    private var unreadStatus:NSStatusItem!
    private var bubble:FloatingPanel!
    private var bubbleHost:NSHostingView<AnyView>!
    private var positioningBubble = false
    private var cancellables = Set<AnyCancellable>()
    func applicationDidFinishLaunching(_ notification:Notification) {
        NSApp.setActivationPolicy(.accessory)
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        let openItem = NSMenuItem(title:"打开白龙面板",action:#selector(showPanel),keyEquivalent:"1")
        openItem.target = self;appMenu.addItem(openItem)
        let characterItem = NSMenuItem(title:"显示角色",action:#selector(showCharacter),keyEquivalent:"2")
        characterItem.target = self;appMenu.addItem(characterItem);appMenu.addItem(.separator())
        let quitItem = NSMenuItem(title:"退出白龙",action:#selector(quit),keyEquivalent:"q")
        quitItem.target = self;appMenu.addItem(quitItem)
        appItem.submenu = appMenu;main.addItem(appItem);NSApp.mainMenu = main
        unreadStatus = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        unreadStatus.button?.target=self;unreadStatus.button?.action = #selector(acknowledgeAll)
        unreadStatus.button?.toolTip="点击将所有完成提醒标为已读"
        status = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        status.button?.image = StatusBarIcon.load() ?? NSImage(systemSymbolName:"sparkles",accessibilityDescription:"白龙")
        let menu = NSMenu()
        menu.addItem(withTitle:"打开白龙面板",action:#selector(showPanel),keyEquivalent:"")
        menu.addItem(withTitle:"显示角色",action:#selector(showCharacter),keyEquivalent:"")
        menu.addItem(withTitle:"隐藏角色",action:#selector(hideCharacter),keyEquivalent:"")
        menu.addItem(withTitle:"全部标为已读",action:#selector(acknowledgeAll),keyEquivalent:"")
        menu.addItem(withTitle:"导入角色图片…",action:#selector(importCharacter),keyEquivalent:"")
        menu.addItem(.separator())
        menu.addItem(withTitle:"刷新数据",action:#selector(refresh),keyEquivalent:"")
        menu.addItem(.separator())
        menu.addItem(withTitle:"退出白龙",action:#selector(quit),keyEquivalent:"q")
        for item in menu.items { item.target = self };status.menu = menu
        // The app menu and the menu-bar icon must expose the same controls.
        appMenu.removeAllItems()
        for item in menu.items {
            if let copy = item.copy() as? NSMenuItem { appMenu.addItem(copy) }
        }
        appMenu.items.first?.keyEquivalent="1"
        appMenu.items.first(where: { $0.action == #selector(showCharacter) })?.keyEquivalent="2"
        panel = FloatingPanel(contentRect:NSRect(x:0,y:0,width:780,height:740),styleMask:[.titled,.closable,.resizable,.fullSizeContentView],backing:.buffered,defer:false)
        panel.title = "白龙 · Codex 桌面助手"
        panel.titleVisibility = .hidden;panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false;panel.hidesOnDeactivate = false;panel.isMovableByWindowBackground = true
        panel.minSize = NSSize(width:720,height:640)
        panel.contentView = NSHostingView(rootView:Dashboard(store:store).padding(.top,24))
        panel.setFrameAutosaveName("BailongDashboard");if !panel.setFrameUsingName("BailongDashboard") { panel.center() };panel.delegate = self
        character = CharacterPanel(contentRect:NSRect(x:0,y:0,width:245,height:320),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        character.isOpaque = false;character.backgroundColor = .clear;character.hasShadow = false
        character.hidesOnDeactivate = false;character.isMovableByWindowBackground = false;character.isReleasedWhenClosed = false
        character.contentView = NSHostingView(rootView:CompanionView(store:store,open:{ [weak self] in self?.showPanel() }))
        character.delegate = self
        character.setFrameAutosaveName("BailongCharacter")
        if !character.setFrameUsingName("BailongCharacter"),let screen = NSScreen.main { character.setFrameOrigin(NSPoint(x:screen.visibleFrame.maxX - 280,y:screen.visibleFrame.minY + 50)) }
        bubble = FloatingPanel(contentRect:.zero,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        bubble.isOpaque = false;bubble.backgroundColor = .clear;bubble.hasShadow = true
        bubble.hidesOnDeactivate = false;bubble.isReleasedWhenClosed = false
        bubble.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary,.stationary]
        bubbleHost = NSHostingView(rootView:AnyView(BubbleView(store:store,openDetails:{ [weak self] in self?.showPanel() }).onExitCommand { [weak self] in self?.store.bubbleVisible = false }))
        bubble.contentView = bubbleHost
        store.$bubbleVisible.receive(on:RunLoop.main).sink { [weak self] visible in
            guard let self else { return }
            if visible {
                self.positionBubble()
                if self.store.bubbleVisible {
                    if self.store.bubblePage == "data" { self.bubble.makeKeyAndOrderFront(nil) }
                    else { self.bubble.orderFrontRegardless() }
                }
            }
            else { self.bubble.orderOut(nil);self.store.monologueEnd = nil }
        }.store(in:&cancellables)
        store.$bubblePage.receive(on:RunLoop.main).sink { [weak self] _ in
            DispatchQueue.main.async { self?.positionBubble() }
        }.store(in:&cancellables)
        store.objectWillChange.debounce(for:.milliseconds(30),scheduler:RunLoop.main).sink { [weak self] _ in
            guard let self,self.store.bubbleVisible else { return }
            // Quota responses and context rows can change the card's height while it is open.
            self.bubbleHost.needsLayout = true
            self.positionBubble()
        }.store(in:&cancellables)
        store.$customName.receive(on:RunLoop.main).sink { [weak self] _ in
            guard let self else { return };let name = self.store.petName
            self.panel.title = name + " · Codex 桌面助手"
            appMenu.items.first?.title = "打开" + name + "面板"
            appMenu.items.last?.title = "退出" + name
            menu.items.first?.title = "打开" + name + "面板"
            menu.items.last?.title = "退出" + name
            menu.items.first(where: { $0.action == #selector(self.showCharacter) })?.title = "显示" + name
            menu.items.first(where: { $0.action == #selector(self.hideCharacter) })?.title = "隐藏" + name
            appMenu.items.first(where: { $0.action == #selector(self.showCharacter) })?.title = "显示" + name
            appMenu.items.first(where: { $0.action == #selector(self.hideCharacter) })?.title = "隐藏" + name
            self.status.button?.setAccessibilityLabel(name)
        }.store(in:&cancellables)
        store.$alwaysOnTop.sink { [weak self] value in
            self?.panel?.level = value ? .floating:.normal
            self?.character?.level = value ? .floating:.normal
            self?.bubble?.level = value ? .floating:.normal
        }.store(in:&cancellables)
        store.$characterVisible.sink { [weak self] visible in
            if visible { self?.character?.orderFrontRegardless() } else { self?.character?.orderOut(nil);self?.store.bubbleVisible = false }
        }.store(in:&cancellables)
        store.$characterScale.sink { [weak self] scale in
            guard let window = self?.character else { return }
            self?.store.bubbleVisible = false
            window.setContentSize(NSSize(width:210 * scale + 35,height:235 * scale + 85))
            self?.clamp(window)
        }.store(in:&cancellables)
        clamp(panel);clamp(character)
        store.$unread.sink { [weak self] keys in
            self?.unreadStatus.button?.title = String(keys.count)
            self?.unreadStatus.isVisible = !keys.isEmpty
            self?.unreadStatus.button?.setAccessibilityLabel("\(keys.count) 个完成提醒，点击全部标为已读")
        }.store(in:&cancellables)
        store.start();showPanel()
    }
    private func clamp(_ window:NSWindow) {
        guard !NSScreen.screens.contains(where: { $0.visibleFrame.contains(window.frame) }),let screen = NSScreen.main else { return }
        let area = screen.visibleFrame
        window.setFrameOrigin(NSPoint(x:min(max(window.frame.minX,area.minX),max(area.minX,area.maxX-window.frame.width)),y:min(max(window.frame.minY,area.minY),max(area.minY,area.maxY-window.frame.height))))
    }
    private func positionBubble() {
        guard !positioningBubble,let character,let bubble,let bubbleHost else { return }
        positioningBubble = true;defer { positioningBubble = false }
        bubbleHost.layoutSubtreeIfNeeded()
        let size = bubbleHost.fittingSize
        guard size.width > 0,size.height > 0,let screen = character.screen ?? NSScreen.main else { return }
        let area = screen.visibleFrame
        if let frame = PetPresentation.bubbleFrame(pet:character.frame,size:size,screen:area) { if bubble.frame != frame { bubble.setFrame(frame,display:true) } }
        else {
            // Moving to a screen corner frees a full side for tall settings pages.
            character.setFrameOrigin(NSPoint(x:area.maxX-character.frame.width,y:area.minY))
            if let frame = PetPresentation.bubbleFrame(pet:character.frame,size:size,screen:area) { bubble.setFrame(frame,display:true) }
            else { store.bubbleVisible = false }
        }
        let frame=bubble.frame;let pet=character.frame
        let edge = frame.minY >= pet.maxY ? "bottom":frame.maxY <= pet.minY ? "top":frame.maxX <= pet.minX ? "right":"left"
        let offset = edge == "bottom" || edge == "top" ? (pet.midX-frame.minX)/frame.width:1-(pet.midY-frame.minY)/frame.height
        if store.bubbleTail != edge { store.bubbleTail = edge }
        let clamped = min(0.85,max(0.15,offset))
        if abs(store.bubbleTailPosition-clamped) > 0.001 { store.bubbleTailPosition = clamped }
    }
    func windowDidMove(_ notification:Notification) { if notification.object as? NSWindow === character,store.bubbleVisible,!store.draggingCharacter { positionBubble() } }
    func windowWillClose(_ notification:Notification) { if notification.object as? NSWindow === panel { store.dashboardVisible = false } }
    @objc func showPanel() { store.dashboardVisible = true;NSApp.activate(ignoringOtherApps:true);panel.makeKeyAndOrderFront(nil) }
    @objc func showCharacter() { store.characterVisible = true;character.orderFrontRegardless() }
    @objc func hideCharacter() { store.characterVisible = false }
    @objc func acknowledgeAll() { for key in Array(store.unread) { store.acknowledge(key) } }
    @objc func importCharacter() { store.importCharacter() }
    @objc func refresh() { store.refresh();store.refreshQuota() }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification:Notification) { store.stop() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication) -> Bool { false }
}

if CommandLine.arguments.contains("--probe") {
    let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/sessions")
    let reader = LogReader()
    let urls = LogReader.recentLogs(root:root,limit:5)
    let rows = urls.compactMap { try? reader.refresh($0) }
    print("Readable sessions: \(rows.filter { $0.id != nil }.count)")
    print("Desktop origins: \(Set(rows.map(\.origin)).sorted().joined(separator:", "))")
    print("Rows with previous-input and capacity: \(rows.filter { $0.previousInput != nil && $0.capacity != nil }.count)")
    if let executable = QuotaClient.discover() {
        do { let quota = try QuotaClient().read(executable:executable);print("Quota windows: \(quota.windows.map { "\($0.label): \($0.remainingPercent)% remaining" }.joined(separator:", "))") }
        catch { print("Quota unavailable: \(error.localizedDescription)");exit(2) }
    } else { print("Codex executable unavailable");exit(2) }
} else {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.run()
}
