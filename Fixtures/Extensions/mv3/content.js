window.sereinIsolatedSecret = 'extension-only';
browser.runtime.sendMessage({type:'probe'}).then(result => {
  document.documentElement.dataset.sereinMV3=JSON.stringify(result);
}).catch(error => {document.documentElement.dataset.sereinMV3=JSON.stringify({ok:false,error:String(error)});});
