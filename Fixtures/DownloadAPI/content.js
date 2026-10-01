browser.runtime.sendMessage({type:'download-api-reference'}).then(result=>{
  document.documentElement.dataset.downloadReference=JSON.stringify(result);
}).catch(error=>{
  document.documentElement.dataset.downloadReference=JSON.stringify({error:String(error)});
});
