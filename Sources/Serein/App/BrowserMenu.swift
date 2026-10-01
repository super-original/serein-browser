import AppKit
import SereinCore

@MainActor final class BrowserMenu: NSObject, NSMenuItemValidation {
    weak var manager: BrowserManager?
    init(manager: BrowserManager) {self.manager=manager}
    private func item(_ title: String,_ key: String="",mods: NSEvent.ModifierFlags = .command,action: Selector) -> NSMenuItem {
        let item=NSMenuItem(title:title,action:action,keyEquivalent:key);item.keyEquivalentModifierMask=mods;item.target=self;return item
    }
    func install() {
        let bar=NSMenu()
        func submenu(_ name: String,_ items:[NSMenuItem]) {let parent=NSMenuItem();let menu=NSMenu(title:name);items.forEach{menu.addItem($0)};parent.submenu=menu;bar.addItem(parent)}
        submenu("Serein",[item("About Serein",action:#selector(about)),item("Settings…",",",action:#selector(settings)),.separator(),item("Hide Serein","h",action:#selector(hide)),item("Quit Serein","q",action:#selector(quit))])
        submenu("File",[item("New Tab","t",action:#selector(newTab)),item("New Folder…",action:#selector(newFolder)),item("New Window","n",action:#selector(newWindow)),item("New Private Window","n",mods:[.command,.shift],action:#selector(privateWindow)),item("Open File…","o",action:#selector(openFile)),.separator(),item("Close Tab","w",action:#selector(closeTab)),item("Reopen Closed Tab","t",mods:[.command,.shift],action:#selector(reopen))])
        let edit=NSMenu(title:"Edit")
        for (name,key,selector) in [("Undo","z",Selector(("undo:"))),("Redo","Z",Selector(("redo:"))),("Cut","x",#selector(NSText.cut(_:))),("Copy","c",#selector(NSText.copy(_:))),("Paste","v",#selector(NSText.paste(_:))),("Select All","a",#selector(NSText.selectAll(_:)))] {edit.addItem(NSMenuItem(title:name,action:selector,keyEquivalent:key))}
        edit.addItem(.separator());edit.addItem(item("Find in Page…","f",action:#selector(find)));let editParent=NSMenuItem();editParent.submenu=edit;bar.addItem(editParent)
        submenu("View",[item("Focus Address","l",action:#selector(address)),item("Reload","r",action:#selector(reload)),item("Stop Loading",".",action:#selector(stop)),.separator(),item("Toggle Sidebar","s",mods:[.command,.shift],action:#selector(sidebar)),item("Toggle Compact Mode","c",mods:[.command,.option],action:#selector(compact)),item("Split with Next Tab","s",mods:[.command,.option],action:#selector(split)),item("Split Into Rows","h",mods:[.command,.option],action:#selector(splitRows)),item("Split Into Columns","v",mods:[.command,.option],action:#selector(splitColumns)),item("Split Into Grid","g",mods:[.command,.option],action:#selector(splitGrid)),item("Exit Split View","u",mods:[.command,.option],action:#selector(unsplit)),item("Close Preview","\u{1b}",mods:[],action:#selector(closeGlance)),.separator(),item("Zoom In","+",action:#selector(zoomIn)),item("Zoom Out","-",action:#selector(zoomOut)),item("Actual Size","0",action:#selector(actualSize)),item("Enter Full Screen","f",mods:[.command,.control],action:#selector(fullscreen))])
        submenu("History",[item("Back","[",action:#selector(back)),item("Forward","]",action:#selector(forward)),item("History","y",action:#selector(history))])
        submenu("Bookmarks",[item("Bookmark This Page","d",action:#selector(bookmark)),item("Show Bookmarks",action:#selector(bookmarks))])
        submenu("Tools",[item("Downloads","j",action:#selector(downloads)),item("Extensions",action:#selector(extensions)),.separator(),item("Save Page Screenshot…",action:#selector(savePageScreenshot))])
        submenu("Window",[item("Minimize","m",action:#selector(minimize)),item("Next Tab","\t",mods:.control,action:#selector(nextTab)),item("Previous Tab","\t",mods:[.control,.shift],action:#selector(previousTab))])
        NSApp.mainMenu=bar;NSApp.windowsMenu=bar.items.last?.submenu
    }
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item.action == #selector(savePageScreenshot) {guard let session=manager?.active else{return false};return PageSnapshot.available(in:session)}
        if item.action == #selector(bookmark) {return manager?.active?.state.selectedTab != nil && manager?.active?.window?.attachedSheet==nil}
        if item.action == #selector(newFolder) {return manager != nil && manager?.active?.window?.attachedSheet==nil}
        if item.action == #selector(closeGlance) {return manager?.active?.state.activeGlance != nil && manager?.active?.window?.attachedSheet == nil && manager?.active?.findVisible == false && manager?.active?.addressFocused == false && manager?.active?.current?.loadedWebView?.fullscreenState == .notInFullscreen}
        if item.action == #selector(back) {return manager?.active?.current?.canGoBack ?? false}
        if item.action == #selector(forward) {return manager?.active?.current?.canGoForward ?? false}
        if item.action == #selector(unsplit) {return !(manager?.active?.state.splitTabIDs.isEmpty ?? true)}
        if let action=item.action,[#selector(split),#selector(splitRows),#selector(splitColumns),#selector(splitGrid)].contains(action) {
            guard let state=manager?.active?.state else{return false}
            return state.visibleTabs.contains{$0.id != state.selectedTabID}
        }
        if item.action == #selector(reopen) {return !(manager?.active?.state.closedTabs.isEmpty ?? true)}
        return true
    }
    @objc func newTab(){if let session=manager?.active{session.newTab()}else{manager?.newWindow()}}
    @objc func newFolder(){
        guard let manager else{return}
        let session=manager.active ?? manager.newWindow()
        guard session.window?.attachedSheet==nil else{return}
        session.folderEditor = .init()
    }
    @objc func closeGlance(){manager?.active?.closeGlance()}
    @objc func newWindow(){manager?.newWindow()}
    @objc func privateWindow(){manager?.newWindow(isPrivate:true)}
    @objc func closeTab(){if let session=manager?.active,let id=session.state.selectedTabID{session.close(id)}}
    @objc func reopen(){manager?.active?.reopen()}
    @objc func address(){manager?.active?.compactRevealed=true;manager?.active?.addressFocused=true}
    @objc func reload(){manager?.active?.current?.reload()}
    @objc func stop(){manager?.active?.current?.webView.stopLoading()}
    @objc func back(){manager?.active?.current?.goBack()}
    @objc func forward(){manager?.active?.current?.goForward()}
    @objc func find(){manager?.active?.findVisible=true}
    @objc func history(){manager?.active?.libraryPanel = .history}
    @objc func bookmarks(){manager?.active?.libraryPanel = .bookmarks}
    @objc func bookmark(){manager?.active?.bookmark()}
    @objc func downloads(){manager?.active?.libraryPanel = .downloads}
    @objc func extensions(){manager?.active?.libraryPanel = .extensions}
    @objc func savePageScreenshot(){
        guard let session=manager?.active else{return}
        Task {do{_ = try await PageSnapshot.save(in:session)}catch{session.error=error.localizedDescription}}
    }
    @objc func settings(){if manager?.active==nil{manager?.newWindow()};manager?.active?.libraryPanel = .settings}
    @objc func sidebar(){guard let s=manager?.active else{return};s.state.sidebar=s.state.sidebar == .collapsed ? .expanded : .collapsed}
    @objc func compact(){guard let s=manager?.active else{return};s.state.sidebar=s.state.sidebar == .compact ? .expanded : .compact;s.compactRevealed=false}
    @objc func split(){guard let s=manager?.active,let other=s.state.adjacentVisibleTab(1),other != s.state.selectedTabID else{return};s.state.split(with:other);s.contentFocusRequest=s.state.selectedTabID}
    @objc func splitRows(){arrangeSplit(.rows)}
    @objc func splitColumns(){arrangeSplit(.columns)}
    @objc func splitGrid(){arrangeSplit(.grid)}
    private func arrangeSplit(_ layout:SplitLayout) {
        guard let session=manager?.active else{return}
        if session.state.splitTabIDs.isEmpty {
            guard let next=session.state.adjacentVisibleTab(1),next != session.state.selectedTabID else{return}
            session.state.split(with:next)
        }
        session.state.setSplitLayout(layout)
        session.contentFocusRequest=session.state.selectedTabID
    }
    @objc func unsplit(){guard let session=manager?.active else{return};session.state.clearSplit();session.contentFocusRequest=session.state.selectedTabID}
    @objc func zoomIn(){if let runtime=manager?.active?.current{runtime.setZoom(min(5,runtime.webView.pageZoom+0.1))}}
    @objc func zoomOut(){if let runtime=manager?.active?.current{runtime.setZoom(max(0.25,runtime.webView.pageZoom-0.1))}}
    @objc func actualSize(){manager?.active?.current?.setZoom(0)}
    @objc func fullscreen(){manager?.active?.window?.toggleFullScreen(nil)}
    @objc func minimize(){manager?.active?.window?.miniaturize(nil)}
    @objc func nextTab(){cycle(1)}
    @objc func previousTab(){cycle(-1)}
    private func cycle(_ direction:Int){guard let s=manager?.active,let id=s.state.adjacentVisibleTab(direction) else{return};s.select(id)}
    @objc func hide(){NSApp.hide(nil)}
    @objc func quit(){NSApp.terminate(nil)}
    @objc func about(){NSApp.orderFrontStandardAboutPanel(options:[.applicationName:"Serein",.applicationVersion:"0.1.0",.credits:NSAttributedString(string:"Native WebKit browser for macOS 27. Development build. Extension compatibility is incomplete.")])}
    @objc func openFile(){guard let s=manager?.active,let w=s.dialogWindow else{return};let panel=NSOpenPanel();panel.beginSheetModal(for:w){result in if result == .OK,let url=panel.url{let id=s.newTab();s.runtime(id).openFile(url)}}}
}
