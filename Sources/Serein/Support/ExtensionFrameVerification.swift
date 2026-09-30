import WebKit

@MainActor enum ExtensionFrameVerification {
    static func run(session:BrowserSession,generation:Int) async -> [RuntimeVerification.Result] {
        let name="mv\(generation)"
        let id=session.newTab(url:"http://127.0.0.1:8765/frame-parent.html",select:false)
        let view=session.runtime(id).webView
        defer{session.close(id,ask:false)}
        var evidence:[String:[String:String]]=[:]
        for _ in 0..<50 {
            if let json=try? await view.evaluateJavaScript("JSON.stringify(window.frameEvidence || {})") as? String,
               let data=json.data(using:.utf8),let value=try? JSONDecoder().decode([String:[String:String]].self,from:data) {
                evidence=value
                if value["allowed"]?["marker"]==name,value["outside"] != nil {break}
            }
            try? await Task.sleep(for:.milliseconds(100))
        }
        let detail=String(describing:evidence)
        return [
            .init(name:name+"-same-origin-subframe-injection",passed:evidence["allowed"]?["marker"]==name,detail:detail),
            .init(name:name+"-unrequested-origin-subframe-excluded",passed:evidence["outside"]?["marker"]=="",detail:detail),
            .init(name:name+"-subframe-isolated-world",passed:evidence["allowed"]?["pageSecret"]=="undefined" && evidence["outside"]?["pageSecret"]=="undefined",detail:detail)
        ]
    }
}
