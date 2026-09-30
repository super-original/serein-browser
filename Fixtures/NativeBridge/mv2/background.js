// Diagnostic only: test whether a missing namespace can be installed in this
// execution world. This is NOT a downloads implementation and returns no data.
let namespaceInstalled = false;
let namespaceError = null;
try {
  if (typeof browser.downloads === 'undefined') {
    Object.defineProperty(browser, 'downloads', {
      configurable: true,
      value: Object.freeze({__sereinTransportProbe: () =>
        browser.runtime.sendNativeMessage('dev.serein.compat.probe', {operation:'probe'})})
    });
    namespaceInstalled = typeof browser.downloads.__sereinTransportProbe === 'function';
  }
} catch (error) { namespaceError = String(error); }
const workerContext = typeof ServiceWorkerGlobalScope !== 'undefined' &&
  globalThis instanceof ServiceWorkerGlobalScope;

browser.runtime.onMessage.addListener((message, sender, reply) => {
  if (message.type !== 'native-probe') return false;
  (async () => {
    try {
      const response = namespaceInstalled
        ? await browser.downloads.__sereinTransportProbe()
        : await browser.runtime.sendNativeMessage('dev.serein.compat.probe', {operation:'probe'});
      let unknownRejected = false;
      try { await browser.runtime.sendNativeMessage('dev.serein.unregistered', {operation:'probe'}); }
      catch (_) { unknownRejected = true; }
      reply({allowed:true,response,unknownRejected,namespaceInstalled,namespaceError,workerContext});
    } catch (error) { reply({allowed:false,error:String(error),namespaceInstalled,namespaceError,workerContext}); }
  })();
  return true;
});
