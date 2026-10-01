import Foundation

@MainActor enum ExtensionNavigationTrace {
    private static var remaining=300
    static func record(_ message:@autoclosure ()->String) {
        guard remaining>0,ProcessInfo.processInfo.arguments.contains("--integration-test") else{return}
        remaining -= 1
        print(message())
    }
}
