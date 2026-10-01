const cookieEvents=[];
browser.cookies.onChanged.addListener(change=>{
  if(change.cookie.name.startsWith('serein_network_')) cookieEvents.push({name:change.cookie.name,removed:change.removed,cause:change.cause,value:change.cookie.value});
});
browser.runtime.onMessage.addListener(message=>{
  if(message?.kind!=='network-fixture') return;
  return (async()=>{
    try {
      const name=message.name;
      if(!/^serein_network_[a-zA-Z0-9_]+$/.test(name)) throw new Error('Invalid fixture cookie name');
      if(message.operation==='fetch' || message.operation==='redirect') {
        const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),3000);
        try {
          const path=message.operation==='redirect' ? 'extension-network-redirect' : 'extension-network.json';
          const response=await fetch('http://localhost:8765/'+path+'?case='+encodeURIComponent(message.case),{credentials:'omit',cache:'no-store',signal:controller.signal});
          return {ok:response.ok,status:response.status,body:await response.json(),url:response.url,worker:typeof document==='undefined'};
        } finally {clearTimeout(timer);}
      }
      const details={url:'http://localhost:8765/',name};
      if(message.operation==='set') return {ok:true,cookie:await browser.cookies.set({...details,value:'fixture-value',path:'/',sameSite:'lax',expirationDate:Math.floor(Date.now()/1000)+300})};
      if(message.operation==='get') return {ok:true,cookie:await browser.cookies.get(details)};
      if(message.operation==='remove') return {ok:true,removed:await browser.cookies.remove(details)};
      if(message.operation==='events') return {ok:true,events:cookieEvents.filter(change=>change.name===name)};
      throw new Error('Unknown fixture operation');
    } catch(error){return {ok:false,error:String(error),worker:typeof document==='undefined'};}
  })();
});
