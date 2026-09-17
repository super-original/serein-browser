browser.runtime.onMessage.addListener((message, sender, reply) => {
  if (message.type !== 'probe') return false;
  (async () => {
    const previous = await browser.storage.local.get('count');
    const count = (previous.count || 0) + 1;
    await browser.storage.local.set({count});
    const tabs = await browser.tabs.query({});
    reply({ok:true,count,tabCount:tabs.length,senderTab:typeof sender.tab?.id === 'number'});
  })().catch(error => reply({ok:false,error:String(error)}));
  return true;
});
