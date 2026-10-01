import AppKit
import WebKit
import ImageIO

/// Same-origin favicons fetched with the page's original fetch function.
/// Page-world execution preserves its enforced Content Security Policy.
/// No native cookie copying, cross-origin request, or persistent icon cache.
@MainActor enum PageIcon {
    @MainActor private final class Reply {
        var continuation:CheckedContinuation<String?,Never>?
        var deadline:Task<Void,Never>?
        init(_ continuation:CheckedContinuation<String?,Never>){self.continuation=continuation}
        func finish(_ value:String?) {
            guard let continuation else{return}
            self.continuation=nil;deadline?.cancel();deadline=nil;continuation.resume(returning:value)
        }
    }
    static func bootstrap(key:String)->WKUserScript {
        let source="""
        (()=>{
        const fetch=globalThis.fetch.bind(globalThis);
        const URL=globalThis.URL,AbortController=globalThis.AbortController,Image=globalThis.Image,Blob=globalThis.Blob;
        Object.defineProperty(globalThis,'\(key)',{value:async()=>{
        const candidate=document.querySelector('link[rel~="icon" i]')?.getAttribute('href') || '/favicon.ico';
        let url;try{url=new URL(candidate,document.baseURI);}catch{return null;}
        if(!['http:','https:'].includes(url.protocol)||url.origin!==location.origin||url.username||url.password)return null;
        const controller=new AbortController();const timer=setTimeout(()=>controller.abort(),3000);
        let reader,objectURL;
        try {
          const response=await fetch(url.href,{credentials:'same-origin',redirect:'error',signal:controller.signal});
          if(!response.ok||!response.body)return null;
          const size=Number(response.headers.get('content-length'));
          if(size>262144)return null;
          reader=response.body.getReader();const chunks=[];let count=0;
          for(;;){const {done,value}=await reader.read();if(done)break;count+=value.length;if(count>262144)return null;chunks.push(value);}
          if((response.headers.get('content-type')||'').split(';')[0].trim().toLowerCase()==='image/svg+xml'){
            objectURL=URL.createObjectURL(new Blob(chunks,{type:'image/svg+xml'}));
            const image=new Image();
            await new Promise((resolve,reject)=>{
              const finish=(error)=>{image.onload=null;image.onerror=null;controller.signal.removeEventListener('abort',abort);error?reject(error):resolve();};
              const abort=()=>{image.src='';finish(new Error('Icon deadline'));};
              image.onload=()=>finish();image.onerror=()=>finish(new Error('Invalid SVG image'));
              if(controller.signal.aborted){abort();return;}
              controller.signal.addEventListener('abort',abort,{once:true});image.src=objectURL;
            });
            const width=image.naturalWidth,height=image.naturalHeight;
            if(!width||!height||width>1024||height>1024)return null;
            const canvas=document.createElement('canvas'),scale=32/Math.max(width,height);
            canvas.width=Math.max(1,Math.round(width*scale));canvas.height=Math.max(1,Math.round(height*scale));
            const context=canvas.getContext('2d');if(!context)return null;
            context.drawImage(image,0,0,canvas.width,canvas.height);
            const png=canvas.toDataURL('image/png');return png.startsWith('data:image/png;base64,')?png.substring(22):null;
          }
          let binary='';for(const chunk of chunks){for(const byte of chunk)binary+=String.fromCharCode(byte);}
          return btoa(binary);
        } catch{return null;}
        finally{clearTimeout(timer);controller.abort();if(objectURL)URL.revokeObjectURL(objectURL);if(reader)try{await reader.cancel();}catch{}}
        },writable:false,configurable:false,enumerable:false});
        })();
        """
        return WKUserScript(source:source,injectionTime:.atDocumentStart,forMainFrameOnly:true,in:.page)
    }
    static func load(from view:WKWebView,key:String) async->NSImage? {
        guard ["http","https"].contains(view.url?.scheme?.lowercased() ?? "") else{return nil}
        let encoded:String?=await withCheckedContinuation {(continuation:CheckedContinuation<String?,Never>) in
        let reply=Reply(continuation)
        reply.deadline=Task {try? await Task.sleep(for:.seconds(4));if !Task.isCancelled{reply.finish(nil)}}
        view.callAsyncJavaScript("return await globalThis[key]?.();",arguments:["key":key],in:nil,in:.page) {result in
            switch result {case .success(let value):reply.finish(value as? String);case .failure:reply.finish(nil)}
        }
        }
        guard !Task.isCancelled,let encoded,encoded.utf8.count<=349_528,let data=Data(base64Encoded:encoded),data.count<=262_144,
              let source=CGImageSourceCreateWithData(data as CFData,nil),
              let type=CGImageSourceGetType(source) as String?,
              ["public.png","public.jpeg","public.tiff","com.compuserve.gif","com.microsoft.ico","org.webmproject.webp"].contains(type),
              let properties=CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [String:Any],
              let width=properties[kCGImagePropertyPixelWidth as String] as? NSNumber,
              let height=properties[kCGImagePropertyPixelHeight as String] as? NSNumber,
              width.intValue>0,height.intValue>0,width.intValue<=1024,height.intValue<=1024 else{return nil}
        let options:[CFString:Any]=[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:32,kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceShouldCacheImmediately:true]
        guard let image=CGImageSourceCreateThumbnailAtIndex(source,0,options as CFDictionary) else{return nil}
        let scale=16/CGFloat(max(image.width,image.height))
        return NSImage(cgImage:image,size:NSSize(width:CGFloat(image.width)*scale,height:CGFloat(image.height)*scale))
    }
}
