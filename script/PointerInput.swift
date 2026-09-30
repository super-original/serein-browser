import CoreGraphics
import Foundation

// Real public event injection for the controlled runner fixture. No TCC changes.
guard CommandLine.arguments.count==3,let x=Double(CommandLine.arguments[1]),let y=Double(CommandLine.arguments[2]),x.isFinite,y.isFinite else {exit(2)}
print("CGPreflightPostEventAccess=\(CGPreflightPostEventAccess())")
let point=CGPoint(x:x,y:y)
for type in [CGEventType.mouseMoved,.leftMouseDown,.leftMouseUp] {
    guard let event=CGEvent(mouseEventSource:nil,mouseType:type,mouseCursorPosition:point,mouseButton:.left) else{exit(3)}
    event.flags = .maskAlternate
    event.post(tap:.cghidEventTap)
    Thread.sleep(forTimeInterval:0.1)
}
