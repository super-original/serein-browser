import AppKit

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
        submenu("File",[item("New Tab","t",action:#selector(newTab)),item("New Window","n",action:#selector(newWindow)),item("New Private Window","n",mods:[.command,.shift],action:#selector(privateWindow)),item("Open File…","o",action:#selector(openFile)),.separator(),item("Close Tab","w",action:#selector(closeTab)),item("Reopen Closed Tab","t",mods:[.command,.shift],action:#selector(reopen))])
        let edit=NSMenu(title:"Edit")
        for (name,key,selector) in [("Undo","z",Selector(("undo:"))),("Redo","Z",Selector(("redo:"))),("Cut","x",#selector(NSText.cut(_:))),("Copy","c",#selector(NSText.copy(_:))),("Paste","v",#selector(NSText.paste(_:))),("Select All","a",#selector(NSText.selectAll(_:)))] {edit.addItem(NSMenuItem(title:name,action:selector,keyEquivalent:key))}
        edit.addItem(.separator());edit.addItem(item("Find in Page…","f",action:#selector(find)));let editParent=NSMenuItem();editParent.submenu=edit;bar.addItem(editParent)
        submenu("View",[item("Focus Address","l",action:#selector(address)),item("Reload","r",action:#selector(reload)),item("Stop Loading",".",action:#selector(stop)),.separator(),item("Toggle Sidebar","s",mods:[.command,.shift],action:#selector(sidebar)),item("Toggle Compact Mode","c",mods:[.command,.option],action:#selector(compact)),item("Split with Next Tab","s",mods:[.command,.option],action:#selector(split)),item("Exit Split View",action:#selector(unsplit)),.separator(),item("Zoom In","+",action:#selector(zoomIn)),item("Zoom Out","-",action:#selector(zoomOut)),item("Actual Size","0",action:#selector(actualSize)),item("Enter Full Screen","f",mods:[.command,.control],action:#selector(fullscreen))])
        submenu("History",[item("Back","[",action:#selector(back)),item("Forward","]",action:#selector(forward)),item("History","y",action:#selector(history))])
        submenu("Bookmarks",[item("Bookmark This Page","d",action:#selector(bookmark)),item("Show Bookmarks",action:#selector(bookmarks))])
        submenu("Tools",[item("Downloads","j",action:#selector(downloads)),item("Extensions",action:#selector(extensions))])
        submenu("Window",[item("Minimize","m",action:#selector(minimize)),item("Next Tab","\t",mods:.control,action:#selector(nextTab)),item("Previous Tab","\t",mods:[.control,.shift],action:#selector(previousTab))])
        NSApp.mainMenu=bar;NSApp.windowsMenu=bar.items.last?.submenu
    }
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item.action == #selector(back) {return manager?.active?.current?.canGoBack ?? false}
        if item.action == #selector(forward) {return manager?.active?.current?.canGoForward ?? false}
        if item.action == #selector(reopen) {return !(manager?.active?.state.closedTabs.isEmpty ?? true)}
        return true
    }
    @objc func newTab(){if let session=manager?.active{session.newTab()}else{manager?.newWindow()}}
    @objc func newWindow(){manager?.newWindow()}
    @objc func privateWindow(){manager?.newWindow(isPrivate:true)}
    @objc func closeTab(){if let session=manager?.active,let id=session.state.selectedTabID{session.close(id)}}
    @objc func reopen(){manager?.active?.reopen()}
    @objc func address(){manager?.active?.compactRevealed=true;manager?.active?.addressFocused=true}
    @objc func reload(){manager?.active?.current?.webView.reload()}
    @objc func stop(){manager?.active?.current?.webView.stopLoading()}
    @objc func back(){manager?.active?.current?.webView.goBack()}
    @objc func forward(){manager?.active?.current?.webView.goForward()}
    @objc func find(){manager?.active?.findVisible=true}
    @objc func history(){manager?.active?.libraryPanel = .history}
    @objc func bookmarks(){manager?.active?.libraryPanel = .bookmarks}
    @objc func bookmark(){manager?.active?.bookmark()}
    @objc func downloads(){manager?.active?.libraryPanel = .downloads}
    @objc func extensions(){manager?.active?.libraryPanel = .extensions}
    @objc func settings(){if manager?.active==nil{manager?.newWindow()};manager?.active?.libraryPanel = .settings}
    @objc func sidebar(){guard let s=manager?.active else{return};s.state.sidebar=s.state.sidebar == .collapsed ? .expanded : .collapsed}
    @objc func compact(){guard let s=manager?.active else{return};s.state.sidebar=s.state.sidebar == .compact ? .expanded : .compact;s.compactRevealed=false}
    @objc func split(){guard let s=manager?.active,let other=s.state.visibleTabs.first(where:{$0.id != s.state.selectedTabID}) else{return};s.state.split(with:other.id)}
    @objc func unsplit(){manager?.active?.state.secondaryTabID=nil}
    @objc func zoomIn(){if let v=manager?.active?.current?.webView{v.pageZoom=min(3,v.pageZoom+0.1)}}
    @objc func zoomOut(){if let v=manager?.active?.current?.webView{v.pageZoom=max(0.3,v.pageZoom-0.1)}}
    @objc func actualSize(){manager?.active?.current?.webView.pageZoom=1}
    @objc func fullscreen(){manager?.active?.window?.toggleFullScreen(nil)}
    @objc func minimize(){manager?.active?.window?.miniaturize(nil)}
    @objc func nextTab(){cycle(1)}
    @objc func previousTab(){cycle(-1)}
    private func cycle(_ direction:Int){guard let s=manager?.active,let i=s.state.visibleTabs.firstIndex(where:{$0.id==s.state.selectedTabID}) else{return};let tabs=s.state.visibleTabs;s.select(tabs[(i+direction+tabs.count)%tabs.count].id)}
    @objc func hide(){NSApp.hide(nil)}
    @objc func quit(){NSApp.terminate(nil)}
    @objc func about(){NSApp.orderFrontStandardAboutPanel(options:[.applicationName:"Serein",.applicationVersion:"0.1.0",.credits:NSAttributedString(string:"Native WebKit browser for macOS 27. Development build. Extension compatibility is incomplete.")])}
    @objc func openFile(){guard let s=manager?.active,let w=s.window else{return};let panel=NSOpenPanel();panel.beginSheetModal(for:w){result in if result == .OK,let url=panel.url{let id=s.newTab();s.runtime(id).webView.loadFileURL(url,allowingReadAccessTo:url.deletingLastPathComponent())}}}
}
