// Only the designated lifecycle page may initiate this destructive fixture.
if (new URL(location.href).searchParams.get('extension') === 'mv2-denied') {
window.sereinIsolatedSecret = 'extension-only';
browser.runtime.sendMessage({type:'probe'}).then(result => {
  document.documentElement.dataset.sereinMV2=JSON.stringify(result);
}).catch(error => {document.documentElement.dataset.sereinMV2=JSON.stringify({ok:false,error:String(error)});});
}
