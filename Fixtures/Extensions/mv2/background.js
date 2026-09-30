browser.runtime.onMessage.addListener((message, sender, reply) => {
  if (message.type !== 'probe') return false;
  (async () => {
    const previous = await browser.storage.local.get('count');
    const count = (previous.count || 0) + 1;
    await browser.storage.local.set({count});
    const createdEvents = [], removedEvents = [];
    const onCreated = tab => createdEvents.push(tab.id);
    const onRemoved = id => removedEvents.push(id);
    browser.tabs.onCreated.addListener(onCreated);
    browser.tabs.onRemoved.addListener(onRemoved);
    let created, duplicate, tabLifecycle;
    try {
      created = await browser.tabs.create({url:'about:blank', active:false, pinned:true});
      const queried = await browser.tabs.get(created.id);
      duplicate = await browser.tabs.duplicate(created.id);
      const copied = await browser.tabs.get(duplicate.id);
      await browser.tabs.remove([created.id, duplicate.id]);
      await browser.tabs.update(sender.tab.id, {active:true});
      // Event delivery is asynchronous relative to promise resolution.
      await new Promise(resolve => setTimeout(resolve, 100));
      tabLifecycle = {createdPinned:queried.pinned, duplicatePinned:copied.pinned,
        distinctIDs:created.id !== duplicate.id, duplicateURL:copied.url === queried.url,
        createdEvents:createdEvents.includes(created.id) && createdEvents.includes(duplicate.id),
        removedEvents:removedEvents.includes(created.id) && removedEvents.includes(duplicate.id)};
    } finally {
      browser.tabs.onCreated.removeListener(onCreated);
      browser.tabs.onRemoved.removeListener(onRemoved);
      for (const tab of [created, duplicate]) if (tab) {
        try { await browser.tabs.remove(tab.id); } catch (_) {}
      }
    }
    const tabs = await browser.tabs.query({});
    reply({ok:true,count,tabLifecycle,tabCount:tabs.length,senderTab:typeof sender.tab?.id === 'number'});
  })().catch(error => reply({ok:false,error:String(error)}));
  return true;
});
