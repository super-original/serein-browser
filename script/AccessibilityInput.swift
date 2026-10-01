import AppKit
import ApplicationServices

// Public Accessibility/event APIs for the exact fixture PID. Never changes TCC.
let arguments=CommandLine.arguments
func fail(_ message:String)->Never {fputs(message+"\n",stderr);exit(1)}
guard arguments.count>=4,let pid=Int32(arguments[1]),pid>1,
      let app=NSRunningApplication(processIdentifier:pid),
      app.bundleIdentifier=="dev.serein.browser" else{fail("Expected the running Serein fixture PID")}
let application=AXUIElementCreateApplication(pid)
AXUIElementSetMessagingTimeout(application,0.25)
let deadline=ProcessInfo.processInfo.systemUptime+(arguments[2]=="press" ? 3.25 : 5.5)
func value(_ element:AXUIElement,_ name:String)->CFTypeRef? {
    var result:CFTypeRef?
    return AXUIElementCopyAttributeValue(element,name as CFString,&result) == .success ? result : nil
}
func text(_ element:AXUIElement,_ name:String)->String {value(element,name) as? String ?? ""}
func elements(_ element:AXUIElement,_ name:String)->[AXUIElement] {value(element,name) as? [AXUIElement] ?? []}
func focused()->AXUIElement? {
    guard let result=value(application,kAXFocusedUIElementAttribute),CFGetTypeID(result)==AXUIElementGetTypeID() else{return nil}
    return unsafeBitCast(result,to:AXUIElement.self)
}
func controls(includeLists:Bool=false)->[AXUIElement] {
    var queue=elements(application,kAXWindowsAttribute),found:[AXUIElement]=[],seen=Set<CFHashCode>()
    while !queue.isEmpty,found.count<500,ProcessInfo.processInfo.systemUptime<deadline {
        let item=queue.removeFirst()
        guard seen.insert(CFHash(item)).inserted else{continue}
        found.append(item)
        // Save/other controls do not need file rows. Extension management
        // explicitly traverses native lists; web documents are always excluded.
        let excluded=includeLists ? ["AXWebArea","AXBrowser"] : ["AXWebArea","AXOutline","AXTable","AXList","AXBrowser"]
        if !excluded.contains(text(item,kAXRoleAttribute)) {
            queue += elements(item,kAXChildrenAttribute)
        }
    }
    return found
}
func describe(_ items:[AXUIElement])->String {
    items.prefix(100).map{element in
        "\(text(element,kAXRoleAttribute)) id=\(text(element,kAXIdentifierAttribute)) title=\(text(element,kAXTitleAttribute)) description=\(text(element,kAXDescriptionAttribute))"
    }.joined(separator:"\n")
}
func key(_ code:CGKeyCode,flags:CGEventFlags=[]) {
    guard NSWorkspace.shared.frontmostApplication?.processIdentifier==pid else{fail("Fixture lost foreground before keyboard input")}
    for down in [true,false] {
        guard let event=CGEvent(keyboardEventSource:nil,virtualKey:code,keyDown:down) else{fail("Could not create keyboard event")}
        event.flags=down ? flags : [];event.post(tap:.cghidEventTap)
    }
    Thread.sleep(forTimeInterval:0.12)
}
func type(_ string:String,throughSystem:Bool=false) {
    guard NSWorkspace.shared.frontmostApplication?.processIdentifier==pid else{fail("Fixture lost foreground before text input")}
    let units=Array(string.utf16)
    for start in stride(from:0,to:units.count,by:16) {
        let chunk=Array(units[start..<min(start+16,units.count)])
        guard let event=CGEvent(keyboardEventSource:nil,virtualKey:0,keyDown:true) else{fail("Could not create text event")}
        event.flags=[]
        chunk.withUnsafeBufferPointer{event.keyboardSetUnicodeString(stringLength:$0.count,unicodeString:$0.baseAddress!)}
        if throughSystem {event.post(tap:.cghidEventTap)} else {event.postToPid(pid)}
        if let up=CGEvent(keyboardEventSource:nil,virtualKey:0,keyDown:false){
            up.flags=[]
            if throughSystem {up.post(tap:.cghidEventTap)} else {up.postToPid(pid)}
        }
        Thread.sleep(forTimeInterval:0.03)
    }
}
func editable(_ element:AXUIElement)->Bool {[kAXTextFieldRole,kAXComboBoxRole,kAXTextAreaRole].contains(text(element,kAXRoleAttribute))}
guard AXIsProcessTrusted() else{fail("Accessibility access is unavailable for this runner helper; no permission settings changed")}
app.activate(options:[])
for _ in 0..<10 {
    if NSWorkspace.shared.frontmostApplication?.processIdentifier==pid {break}
    Thread.sleep(forTimeInterval:0.05)
}
let mode=arguments[2]
if mode=="press" {
    let identifier=arguments[3]
    let allowed=["glance-close":"Close Preview","glance-expand":"Expand Preview","glance-split":"Split Preview","folder-icon-star.fill":"Star","folder-icon-default":"Default Folder"]
    let extensionAccess=identifier.hasPrefix("extension-access-") && UUID(uuidString:String(identifier.dropFirst("extension-access-".count))) != nil
    let downloadRemove=identifier.hasPrefix("download-remove-") && UUID(uuidString:String(identifier.dropFirst("download-remove-".count))) != nil
    let bookmarkEdit=identifier.hasPrefix("bookmark-edit-") && UUID(uuidString:String(identifier.dropFirst("bookmark-edit-".count))) != nil
    guard let label=allowed[identifier] ?? (extensionAccess ? "Requested Access…" : bookmarkEdit ? "Edit…" : downloadRemove ? "Remove from History" : nil) else{fail("Unknown fixture action")}
    let items=controls(includeLists:extensionAccess || bookmarkEdit || downloadRemove)
    let exact=items.filter{text($0,kAXRoleAttribute)==kAXButtonRole && text($0,kAXIdentifierAttribute)==identifier}
    if downloadRemove && exact.count != 1 {fail("Expected the exact download removal identifier")}
    let matching=exact.isEmpty ? items.filter{text($0,kAXRoleAttribute)==kAXButtonRole && [text($0,kAXTitleAttribute),text($0,kAXDescriptionAttribute)].contains(label)} : exact
    guard matching.count==1 else{fail("Expected exactly one \(identifier) control\n"+describe(items))}
    guard AXUIElementPerformAction(matching[0],kAXPressAction as CFString) == .success else{fail("AXPress failed")}
    print("Pressed \(identifier) through \(exact.isEmpty ? "unique native label" : "identifier")")
} else if mode=="unsplit-tab" {
    let identifier=arguments[3]
    guard identifier.hasPrefix("tab-"),UUID(uuidString:String(identifier.dropFirst(4))) != nil else{fail("Expected fixture tab identifier")}
    let items=controls(),matches=items.filter{text($0,kAXIdentifierAttribute)==identifier && text($0,kAXRoleAttribute)==kAXButtonRole}
    guard matches.count==1 else{fail("Expected one native tab control\n"+describe(items))}
    let menuAction=AXUIElementPerformAction(matches[0],kAXShowMenuAction as CFString)
    if menuAction != .success {
        // SwiftUI does not advertise AXShowMenu for this Button on the pinned
        // runtime. Exercise an actual right click on its measured native bounds.
        // The original AX failure remains in the evidence; no model action runs.
        print("AXShowMenu unavailable (\(menuAction.rawValue)); trying native right click")
        guard let position=value(matches[0],kAXPositionAttribute),let size=value(matches[0],kAXSizeAttribute),
              CFGetTypeID(position)==AXValueGetTypeID(),CFGetTypeID(size)==AXValueGetTypeID() else{fail("Missing tab bounds for context click")}
        var point=CGPoint.zero,dimensions=CGSize.zero
        guard AXValueGetValue(unsafeBitCast(position,to:AXValue.self),.cgPoint,&point),
              AXValueGetValue(unsafeBitCast(size,to:AXValue.self),.cgSize,&dimensions),
              point.x.isFinite,point.y.isFinite,dimensions.width>10,dimensions.height>10 else{fail("Invalid tab context-click bounds")}
        let center=CGPoint(x:point.x+dimensions.width/2,y:point.y+dimensions.height/2)
        for type in [CGEventType.mouseMoved,.rightMouseDown,.rightMouseUp] {
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier==pid,
                  let event=CGEvent(mouseEventSource:nil,mouseType:type,mouseCursorPosition:center,mouseButton:.right) else{fail("Fixture lost foreground before context click")}
            event.post(tap:.cghidEventTap);Thread.sleep(forTimeInterval:0.06)
        }
    }
    Thread.sleep(forTimeInterval:0.2)
    var queue=elements(application,kAXChildrenAttribute)+elements(application,kAXWindowsAttribute),seen=Set<CFHashCode>(),menus:[AXUIElement]=[]
    while !queue.isEmpty,seen.count<500,ProcessInfo.processInfo.systemUptime<deadline {
        let item=queue.removeFirst()
        guard seen.insert(CFHash(item)).inserted else{continue}
        if text(item,kAXRoleAttribute)==kAXMenuItemRole,text(item,kAXTitleAttribute)=="Exit Split View" {menus.append(item)}
        // The application menu bar also has View > Exit Split View, which
        // operates on the active group. Never mistake it for the clicked tab's
        // contextual action: exclude the entire menu-bar subtree.
        if !["AXWebArea","AXBrowser","AXTable",kAXMenuBarRole].contains(text(item,kAXRoleAttribute)) {queue += elements(item,kAXChildrenAttribute)}
    }
    guard menus.count==1,AXUIElementPerformAction(menus[0],kAXPressAction as CFString) == .success else{key(53);fail("Expected one contextual Exit Split View item outside the application menu bar; found \(menus.count)")}
    print("Chose Exit Split View through the native tab context menu")
} else if mode=="accessible-unsplit" {
    let identifier=arguments[3]
    guard identifier.hasPrefix("tab-"),UUID(uuidString:String(identifier.dropFirst(4))) != nil else{fail("Expected fixture tab identifier")}
    let matches=controls().filter{text($0,kAXIdentifierAttribute)==identifier && text($0,kAXRoleAttribute)==kAXButtonRole}
    guard matches.count==1 else{fail("Expected one accessible tab")}
    var actions:CFArray?
    guard AXUIElementCopyActionNames(matches[0],&actions) == .success,let names=actions as? [String] else{fail("Accessible tab has no actions")}
    var matching:[String]=[]
    for name in names {
        var description:CFString?
        _=AXUIElementCopyActionDescription(matches[0],name as CFString,&description)
        let label=description.map{$0 as String} ?? ""
        print("Tab action \(name): \(label)")
        if name=="Exit Split View" || label == "Exit Split View" {matching.append(name)}
    }
    guard matching.count==1,AXUIElementPerformAction(matches[0],matching[0] as CFString) == .success else{fail("Expected accessible Exit Split View action")}
    print("Performed the public named accessibility action")
} else if mode=="focus-tab" {
    let identifier=arguments[3]
    guard identifier.hasPrefix("tab-"),UUID(uuidString:String(identifier.dropFirst(4))) != nil else{fail("Expected fixture tab identifier")}
    let items=controls(),matches=items.filter{text($0,kAXIdentifierAttribute)==identifier && text($0,kAXRoleAttribute)==kAXButtonRole}
    guard matches.count==1 else{fail("Expected one native tab control\n"+describe(items))}
    guard AXUIElementSetAttributeValue(matches[0],kAXFocusedAttribute as CFString,kCFBooleanTrue) == .success else{fail("Could not focus native tab control")}
    Thread.sleep(forTimeInterval:0.2)
    guard let current=focused(),text(current,kAXIdentifierAttribute)==identifier else{fail("Native focus did not reach fixture tab: "+(focused().map{describe([$0])} ?? "No focused element"))}
    print("Focused native tab")
} else if mode=="split-tabs" || mode=="split-groups" {
    let identifiers=arguments[3].split(separator:",").map(String.init)
    guard (2...4).contains(identifiers.count),Set(identifiers).count==identifiers.count,
          identifiers.allSatisfy({$0.hasPrefix("tab-") && UUID(uuidString:String($0.dropFirst(4))) != nil}) else{fail("Expected two to four fixture tab identifiers")}
    let items=controls()
    var buttons:[AXUIElement]=[],frames:[CGRect]=[]
    for identifier in identifiers {
        let matches=items.filter{text($0,kAXIdentifierAttribute)==identifier && text($0,kAXRoleAttribute)==kAXButtonRole}
        guard matches.count==1,let position=value(matches[0],kAXPositionAttribute),let size=value(matches[0],kAXSizeAttribute),
              CFGetTypeID(position)==AXValueGetTypeID(),CFGetTypeID(size)==AXValueGetTypeID() else{fail("Split tab control missing or duplicated: \(identifier)\n"+describe(items))}
        var point=CGPoint.zero,dimensions=CGSize.zero
        guard AXValueGetValue(unsafeBitCast(position,to:AXValue.self),.cgPoint,&point),
              AXValueGetValue(unsafeBitCast(size,to:AXValue.self),.cgSize,&dimensions),dimensions.width>10,dimensions.height>10 else{fail("Invalid split tab bounds")}
        buttons.append(matches[0]);frames.append(CGRect(origin:point,size:dimensions))
    }
    if mode=="split-groups" {
        guard frames.count==4,abs(frames[0].minY-frames[1].minY)<2,abs(frames[2].minY-frames[3].minY)<2,
              frames[0].maxX<=frames[1].minX+1,frames[2].maxX<=frames[3].minX+1,
              frames[0].maxY<=frames[2].minY+1 else{fail("Expected two native horizontal split groups: \(frames)")}
        print("Both native split-group rows: \(frames)")
    } else {
        guard zip(frames,frames.dropFirst()).allSatisfy({a,b in abs(a.minY-b.minY)<2 && a.maxX<=b.minX+1}) else{fail("Split tabs are not independent horizontal native controls: \(frames)")}
        guard let last=buttons.last,AXUIElementPerformAction(last,kAXPressAction as CFString) == .success else{fail("Split tab selection failed")}
        print("Native horizontal split controls: \(frames)")
    }
} else if mode=="drag" {
    guard arguments.count==6,["before","after"].contains(arguments[5]) else{fail("Expected source, destination and before/after placement")}
    let items=controls()
    func center(_ identifier:String,fraction:CGFloat=0.5)->CGPoint? {
        let matches=items.filter{text($0,kAXIdentifierAttribute)==identifier && text($0,kAXRoleAttribute)==kAXButtonRole}
        guard matches.count==1,let position=value(matches[0],kAXPositionAttribute),let size=value(matches[0],kAXSizeAttribute),
              CFGetTypeID(position)==AXValueGetTypeID(),CFGetTypeID(size)==AXValueGetTypeID() else{return nil}
        var point=CGPoint.zero,dimensions=CGSize.zero
        guard AXValueGetValue(unsafeBitCast(position,to:AXValue.self),.cgPoint,&point),
              AXValueGetValue(unsafeBitCast(size,to:AXValue.self),.cgSize,&dimensions),dimensions.width>0,dimensions.height>0 else{return nil}
        return CGPoint(x:point.x+dimensions.width/2,y:point.y+dimensions.height*fraction)
    }
    guard let start=center(arguments[3]),let end=center(arguments[4],fraction:arguments[5]=="after" ? 0.75 : 0.25) else{fail("Native drag controls not uniquely located\n"+describe(items))}
    print("Native drag from \(start) to \(end)")
    for step in 0...32 {
        let progress=Double(max(0,min(30,step-1)))/30
        let type:CGEventType=step==0 ? .mouseMoved : step==1 ? .leftMouseDown : step==32 ? .leftMouseUp : .leftMouseDragged
        guard let event=CGEvent(mouseEventSource:nil,mouseType:type,mouseCursorPosition:CGPoint(x:start.x+(end.x-start.x)*progress,y:start.y+(end.y-start.y)*progress),mouseButton:.left) else{fail("Could not create drag event")}
        event.post(tap:.cghidEventTap);Thread.sleep(forTimeInterval:0.03)
    }
} else if mode=="fill" || mode=="fill-only" {
    guard arguments.count==5 else{fail("Expected field identifier and text")}
    let items=controls()
    let matches=items.filter{editable($0) && text($0,kAXIdentifierAttribute)==arguments[3]}
    guard matches.count==1 else{fail("Expected exactly one text field\n"+describe(items))}
    guard AXUIElementSetAttributeValue(matches[0],kAXFocusedAttribute as CFString,kCFBooleanTrue) == .success else{fail("Could not focus field")}
    Thread.sleep(forTimeInterval:0.1)
    key(0,flags:.maskCommand);type(arguments[4])
    Thread.sleep(forTimeInterval:0.15)
    guard text(matches[0],kAXValueAttribute)==arguments[4] else{fail("Field did not receive exact fixture text: \(text(matches[0],kAXValueAttribute))")}
    if mode=="fill" {key(36)}
    print("Entered text in \(arguments[3])")
} else if mode=="expect-text" {
    guard arguments.count==5,arguments[3]=="downloads-result-count" else{fail("Expected download count identifier and text")}
    let items=controls()
    let matches=items.filter{text($0,kAXIdentifierAttribute)==arguments[3]}
    guard matches.count==1,text(matches[0],kAXValueAttribute)==arguments[4] || text(matches[0],kAXTitleAttribute)==arguments[4] else{fail("Expected exact native result count\n"+describe(items))}
    print("Verified native download count: \(arguments[4])")
} else if mode=="prepare-save" {
    guard arguments.count==6 else{fail("Expected directory, filename and initial save name")}
    let path=arguments[3],name=arguments[4],initial=arguments[5]
    guard path.hasPrefix("/"),!path.contains("\n"),!path.contains("\r"),!name.isEmpty,!name.contains("/"),!initial.isEmpty else{fail("Invalid fixture save destination")}
    key(5,flags:[.maskCommand,.maskShift])
    Thread.sleep(forTimeInterval:0.35)
    guard let field=focused(),editable(field) else{fail("Go to Folder editor unavailable")}
    key(0,flags:.maskCommand);type(path,throughSystem:true)
    Thread.sleep(forTimeInterval:0.2)
    guard let entered=focused(),editable(entered),text(entered,kAXValueAttribute)==path else{fail("Go to Folder did not receive exact directory")}
    key(36)
    let initialNames=[initial,(initial as NSString).deletingPathExtension]
    var ready:AXUIElement?
    while ProcessInfo.processInfo.systemUptime<deadline {
        if let field=focused(),editable(field),initialNames.contains(text(field,kAXValueAttribute)) {
            Thread.sleep(forTimeInterval:0.15)
            if let stable=focused(),CFEqual(field,stable),initialNames.contains(text(stable,kAXValueAttribute)) {ready=stable;break}
        }
        Thread.sleep(forTimeInterval:0.05)
    }
    guard let ready else{fail("Save As editor did not regain stable focus\n"+describe(controls()))}
    key(0,flags:.maskCommand);type(name,throughSystem:true)
    Thread.sleep(forTimeInterval:0.2)
    guard text(ready,kAXValueAttribute)==name else{fail("Save As field did not receive exact filename: \(text(ready,kAXValueAttribute))")}
    print("Prepared exact native Save As name; confirmation left untouched")
} else if mode=="pick-file" {
    let path=arguments[3]
    guard path.hasPrefix("/"),!path.contains("\n"),!path.contains("\r") else{fail("Expected absolute fixture path")}
    key(5,flags:[.maskCommand,.maskShift])
    Thread.sleep(forTimeInterval:0.35)
    guard let field=focused(),editable(field) else{fail("Go to Folder did not focus a text field\n"+describe(controls()))}
    // The native open panel can host its editor in an AppKit service process.
    key(0,flags:.maskCommand);type(path,throughSystem:true)
    Thread.sleep(forTimeInterval:0.25)
    guard let entered=focused(),editable(entered),text(entered,kAXValueAttribute)==path else{fail("Entered path differs from focused value: \(focused().map{text($0,kAXValueAttribute)} ?? "<no focused element>")")}
    key(36)
    while ProcessInfo.processInfo.systemUptime<deadline {
        Thread.sleep(forTimeInterval:0.15)
        let items=controls()
        let buttons=items.filter{text($0,kAXRoleAttribute)==kAXButtonRole}
        // The next sheet is an independently exercised consent step; never accept it.
        if buttons.contains(where:{text($0,kAXTitleAttribute)=="Allow"}) {print("File selected; consent left untouched");exit(0)}
        let open=buttons.filter{text($0,kAXTitleAttribute)=="Open" && (value($0,kAXEnabledAttribute) as? Bool)==true}
        if open.count==1 {
            guard AXUIElementPerformAction(open[0],kAXPressAction as CFString) == .success else{fail("Open action failed")}
            print("Pressed native Open");exit(0)
        }
    }
    fail("Native Open did not become available\n"+describe(controls()))
} else {fail("Unknown fixture input mode")}
