// Ignore the pre-existing loopback tab when this temporary add-on is installed.
const api = globalThis.browser || globalThis.chrome;
if (new URL(location.href).searchParams.get('downloads-reference') === 'mv'+api.runtime.getManifest().manifest_version) {
api.runtime.sendMessage({type:'download-api-reference'}).then(result=>{
  document.documentElement.dataset.downloadReference=JSON.stringify(result);
}).catch(error=>{
  document.documentElement.dataset.downloadReference=JSON.stringify({error:String(error)});
});
}
