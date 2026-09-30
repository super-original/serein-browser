import CoreGraphics
import Foundation

// Real public event injection for the controlled runner fixture. No TCC changes.
guard [3,4].contains(CommandLine.arguments.count),let x=Double(CommandLine.arguments[1]),let y=Double(CommandLine.arguments[2]),x.isFinite,y.isFinite else {exit(2)}
print("CGPreflightPostEventAccess=\(CGPreflightPostEventAccess())")
let point=CGPoint(x:x,y:y),mode=CommandLine.arguments.count==4 ? CommandLine.arguments[3] : "option"
guard ["plain","option","right"].contains(mode) else{exit(2)}
let events:[CGEventType]=mode=="right" ? [.mouseMoved,.rightMouseDown,.rightMouseUp] : [.mouseMoved,.leftMouseDown,.leftMouseUp]
for type in events {
    guard let event=CGEvent(mouseEventSource:nil,mouseType:type,mouseCursorPosition:point,mouseButton:mode=="right" ? .right : .left) else{exit(3)}
    event.flags = mode=="option" ? .maskAlternate : []
    event.post(tap:.cghidEventTap)
    Thread.sleep(forTimeInterval:0.1)
}
