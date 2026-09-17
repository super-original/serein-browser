import AppKit
import ScreenCaptureKit

@main enum ScreenCapture {
    static func main() async throws {
        let content=try await SCShareableContent.excludingDesktopWindows(false,onScreenWindowsOnly:true)
        guard let display=content.displays.first else{throw NSError(domain:"SereinCapture",code:1)}
        let filter=SCContentFilter(display:display,excludingWindows:[])
        let config=SCStreamConfiguration();config.width=display.width;config.height=display.height;config.showsCursor=false
        let image=try await SCScreenshotManager.captureImage(contentFilter:filter,configuration:config)
        let rep=NSBitmapImageRep(cgImage:image)
        guard let data=rep.representation(using:.png,properties:[:]) else{throw NSError(domain:"SereinCapture",code:2)}
        try data.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
    }
}
