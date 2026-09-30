import CoreGraphics
import Foundation

public enum WindowPlacement {
    /// Choose the display containing most of the saved window, then keep the
    /// frame inside its usable area. A disconnected display falls back to the
    /// first supplied screen (the caller's preferred/main screen).
    public static func restored(_ saved:[Double]?, screens:[CGRect]) -> CGRect? {
        guard let saved,saved.count==4,saved.allSatisfy(\.isFinite),saved[2]>=640,saved[3]>=400 else{return nil}
        let screens=screens.filter{[$0.minX,$0.minY,$0.width,$0.height].allSatisfy(\.isFinite) && $0.width>0 && $0.height>0 && $0.maxX.isFinite && $0.maxY.isFinite}
        guard var screen=screens.first else{return nil}
        let frame=CGRect(x:saved[0],y:saved[1],width:saved[2],height:saved[3])
        guard frame.maxX.isFinite,frame.maxY.isFinite else{return nil}
        var largest:CGFloat=0
        for candidate in screens {
            let intersection=candidate.intersection(frame)
            let area=intersection.isNull ? 0 : intersection.width*intersection.height
            if area>largest {screen=candidate;largest=area}
        }
        let width=max(640,min(frame.width,screen.width)),height=max(400,min(frame.height,screen.height))
        // On an unusually small display retain the minimum window size and
        // anchor its title bar at the top of the usable screen.
        let x=screen.width<width ? screen.minX : max(screen.minX,min(frame.minX,screen.maxX-width))
        let y=screen.height<height ? screen.maxY-height : max(screen.minY,min(frame.minY,screen.maxY-height))
        return CGRect(x:x,y:y,width:width,height:height)
    }
}
