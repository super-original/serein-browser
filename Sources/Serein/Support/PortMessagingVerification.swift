import WebKit
import SereinCore

@MainActor enum PortMessagingVerification {
    static func run(manager:BrowserManager) async -> [RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        let session=manager.newWindow()
        defer {session.window?.close()}
        for version in [2,3] {
            let host=manager.extensions,id=UUID(),prefix="mv\(version)-ports-"
            func check(_ name:String,_ passed:Bool,_ detail:String=""){results.append(.init(name:prefix+name,passed:passed,detail:detail))}
            let destination=host.root.appendingPathComponent(id.uuidString)
            do {
                let source=Bundle.main.resourceURL!.appendingPathComponent("Fixtures/PortMessaging/mv\(version)")
                try host.prepare(source,at:destination)
                let installed=InstalledExtension(id:id,name:prefix,version:"1.0",enabled:true,permissions:[],hosts:["http://127.0.0.1/*"])
                host.records.append(installed)
                try await host.load(installed)
                func result(_ property:String) async -> [String:Any]? {
                    for _ in 0..<100 {
                        if let text=try? await session.current?.webView.evaluateJavaScript("document.documentElement.dataset.\(property) || null") as? String,
                           let data=text.data(using:.utf8),let value=try? JSONSerialization.jsonObject(with:data) as? [String:Any] {return value}
                        try? await Task.sleep(for:.milliseconds(50))
                    }
                    return nil
                }
                let url="http://127.0.0.1:8765/index.html?port-lifecycle=\(version)-normal"
                session.navigate(url,ask:false)
                let value=await result("portResult")
                let echoes=value?["echoes"] as? [[String:Any]],record=value?["record"] as? [String:Any]
                check("ordered-bidirectional-messages",echoes?.compactMap{$0["sequence"] as? Int}==[0,1,2] && record?["received"] as? [Int]==[0,1,2],String(describing:value))
                check("structured-message-payload",echoes?.allSatisfy{echo in
                    guard let sequence=echo["sequence"] as? Int,let value=echo["value"] as? [String:Any],let items=value["items"] as? [Any] else{return false}
                    return value["text"] as? String=="message \(sequence)" && value["unicode"] as? String=="雪" && items.count==3 && items[0] is NSNull && items[1] as? Bool==true && items[2] as? Int==sequence
                }==true)
                check("sender-main-frame",record?["senderURL"] as? String==url && record?["frameId"] as? Int==0)
                check("explicit-disconnect-delivered",record?["disconnected"] as? Bool==true)
                session.navigate("http://127.0.0.1:8765/index.html?port-lifecycle=\(version)-disable",ask:false)
                let live=await result("portEchoes")
                check("live-port-before-disable",(live?["echoes"] as? [Any])?.count==3)
                await host.setEnabled(id,false)
                var disconnected=false
                for _ in 0..<100 {
                    disconnected=(try? await session.current?.webView.evaluateJavaScript("document.documentElement.dataset.portDisconnected==='true'") as? Bool)==true
                    if disconnected{break};try? await Task.sleep(for:.milliseconds(50))
                }
                check("disable-disconnects-port",live != nil && disconnected)
                await host.remove(id)
            } catch {check("setup",false,error.localizedDescription);await host.remove(id)}
        }
        return results
    }
}
