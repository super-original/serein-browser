// Ignore the pre-existing loopback tab when this temporary add-on is installed.
if (new URL(location.href).searchParams.get('downloads-reference') === 'mv'+browser.runtime.getManifest().manifest_version) {
browser.runtime.sendMessage({type:'download-api-reference'}).then(result=>{
  document.documentElement.dataset.downloadReference=JSON.stringify(result);
}).catch(error=>{
  document.documentElement.dataset.downloadReference=JSON.stringify({error:String(error)});
});
}
