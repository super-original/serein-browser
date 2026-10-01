import AppKit
import CoreGraphics

// Reference-only visibility probe. It neither captures replacement pixels nor
// changes Accessibility, screen-recording, or other privacy permissions.
let args=CommandLine.arguments
func fail(_ message:String)->Never {fputs(message+"\n",stderr);exit(1)}
guard args.count==5,let pid=Int32(args[1]),pid>1,
      let width=Double(args[3]),let height=Double(args[4]),width>0,height>0,
      let app=NSRunningApplication(processIdentifier:pid),
      app.executableURL?.resolvingSymlinksInPath()==URL(fileURLWithPath:args[2]).resolvingSymlinksInPath() else {
    fail("Expected the exact ChromeDriver-owned executable and dimensions")
}
app.activate(options:[])
let deadline=ProcessInfo.processInfo.systemUptime+10
var stableSince:Double?,lastID:Int?
while ProcessInfo.processInfo.systemUptime<deadline {
    guard !app.isTerminated else{fail("Owned reference browser exited")}
    let windows=CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] ?? []
    let matching=windows.filter {item in
        guard (item[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value==pid,
              (item[kCGWindowLayer as String] as? NSNumber)?.intValue==0,
              let bounds=item[kCGWindowBounds as String] as? [String:Double],
              let w=bounds["Width"],let h=bounds["Height"] else{return false}
        return abs(w-width)<=2 && abs(h-height)<=2
    }
    let now=ProcessInfo.processInfo.systemUptime
    if matching.count==1,NSWorkspace.shared.frontmostApplication?.processIdentifier==pid,
       let id=(matching[0][kCGWindowNumber as String] as? NSNumber)?.intValue {
        if id != lastID {lastID=id;stableSince=now}
        if let since=stableSince,now-since>=1 {
            let result:[String:Any]=["pid":pid,"windowID":id,"bounds":matching[0][kCGWindowBounds as String]!,"stableSeconds":now-since,"visible":true]
            let data=try JSONSerialization.data(withJSONObject:result,options:[.sortedKeys])
            print(String(decoding:data,as:UTF8.self));exit(0)
        }
    } else {stableSince=nil;lastID=nil}
    Thread.sleep(forTimeInterval:0.1)
}
fail("Owned reference window did not remain visible at the requested dimensions")
