import CoreGraphics
import Foundation

// Real public event injection for the controlled runner fixture. No TCC changes.
guard [3,4,5].contains(CommandLine.arguments.count),let x=Double(CommandLine.arguments[1]),let y=Double(CommandLine.arguments[2]),x.isFinite,y.isFinite else {exit(2)}
print("CGPreflightPostEventAccess=\(CGPreflightPostEventAccess())")
if CommandLine.arguments.count==5 {
    guard let endX=Double(CommandLine.arguments[3]),let endY=Double(CommandLine.arguments[4]),endX.isFinite,endY.isFinite else{exit(2)}
    for step in 0...22 {
        let progress=Double(max(0,min(20,step-1)))/20
        let type:CGEventType=step==0 ? .mouseMoved : step==1 ? .leftMouseDown : step==22 ? .leftMouseUp : .leftMouseDragged
        guard let event=CGEvent(mouseEventSource:nil,mouseType:type,mouseCursorPosition:CGPoint(x:x+(endX-x)*progress,y:y+(endY-y)*progress),mouseButton:.left) else{exit(3)}
        event.post(tap:.cghidEventTap);Thread.sleep(forTimeInterval:0.03)
    }
    exit(0)
}
let point=CGPoint(x:x,y:y),mode=CommandLine.arguments.count==4 ? CommandLine.arguments[3] : "option"
guard ["plain","option","right"].contains(mode) else{exit(2)}
let events:[CGEventType]=mode=="right" ? [.mouseMoved,.rightMouseDown,.rightMouseUp] : [.mouseMoved,.leftMouseDown,.leftMouseUp]
for type in events {
    guard let event=CGEvent(mouseEventSource:nil,mouseType:type,mouseCursorPosition:point,mouseButton:mode=="right" ? .right : .left) else{exit(3)}
    event.flags = mode=="option" ? .maskAlternate : []
    event.post(tap:.cghidEventTap)
    Thread.sleep(forTimeInterval:0.1)
}
