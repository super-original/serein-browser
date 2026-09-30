browser.runtime.onMessage.addListener((message, sender, reply) => {
  if (message.type !== 'native-probe') return false;
  (async () => {
    try {
      const response = await browser.runtime.sendNativeMessage('dev.serein.compat.probe', {operation:'probe'});
      let unknownRejected = false;
      try { await browser.runtime.sendNativeMessage('dev.serein.unregistered', {operation:'probe'}); }
      catch (_) { unknownRejected = true; }
      reply({allowed:true,response,unknownRejected});
    } catch (error) { reply({allowed:false,error:String(error)}); }
  })();
  return true;
});
