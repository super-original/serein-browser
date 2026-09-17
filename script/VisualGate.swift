import AppKit

// Detect a known regression: title/DOM loads while all page glyphs are absent
// from the actual desktop capture. This gate never uses WKWebView snapshots.
let input=URL(fileURLWithPath:CommandLine.arguments[1])
let output=URL(fileURLWithPath:CommandLine.arguments[2])
guard let bitmap=NSBitmapImageRep(data:try Data(contentsOf:input)),bitmap.pixelsWide==1024,bitmap.pixelsHigh==768 else{fatalError("Unexpected desktop geometry")}
var dark=0
for y in 100..<600 {
    for x in 280..<950 {
        if let color=bitmap.colorAt(x:x,y:y)?.usingColorSpace(.deviceRGB),color.redComponent<0.3,color.greenComponent<0.3,color.blueComponent<0.3 {dark += 1}
    }
}
let result:[String:Any]=["source":input.lastPathComponent,"darkContentPixels":dark,"minimum":1000,"passed":dark>1000,"scope":"Actual desktop capture of light deterministic page. Glyph-presence regression gate, not a complete fidelity or accessibility test."]
try JSONSerialization.data(withJSONObject:result,options:.prettyPrinted).write(to:output)
print("VISUAL_CONTENT_GATE \(dark>1000 ? "PASS" : "FAIL") dark pixels: \(dark)")
exit(dark>1000 ? 0 : 1)
