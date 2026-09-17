import WebKit
import Foundation

@MainActor final class DownloadVerification:NSObject,WKDownloadDelegate {
    let destination:URL
    var completed=false
    var error:String?
    init(destination:URL){self.destination=destination}
    func download(_ download:WKDownload,decideDestinationUsing response:URLResponse,suggestedFilename:String,completionHandler:@escaping @MainActor @Sendable (URL?)->Void){completionHandler(destination)}
    func downloadDidFinish(_ download:WKDownload){completed=true}
    func download(_ download:WKDownload,didFailWithError error:Error,resumeData:Data?){self.error=error.localizedDescription;completed=true}
}
