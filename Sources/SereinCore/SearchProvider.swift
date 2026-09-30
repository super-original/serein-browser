import Foundation

public enum SearchProvider:String,CaseIterable,Sendable {
    case duckDuckGo,google,bing
    public var title:String {
        switch self {case .duckDuckGo:"DuckDuckGo";case .google:"Google";case .bing:"Bing"}
    }
    public var queryPrefix:String {
        switch self {
        case .duckDuckGo:"https://duckduckgo.com/?q="
        case .google:"https://www.google.com/search?q="
        case .bing:"https://www.bing.com/search?q="
        }
    }
}
