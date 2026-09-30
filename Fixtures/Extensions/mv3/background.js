// Controlled real windows API exercise; failures do not abort tab assertions.
async function probeWindows(senderTabId) {
  const createdEvents=[],removedEvents=[];
  const onCreated=window=>createdEvents.push(window.id);
  const onRemoved=id=>removedEvents.push(id);
  let created;
  try {
    browser.windows.onCreated.addListener(onCreated);
    browser.windows.onRemoved.addListener(onRemoved);
    const sender=await browser.tabs.get(senderTabId);
    created=await browser.windows.create({url:'about:blank',focused:false,width:700,height:500});
    const queried=await browser.windows.get(created.id,{populate:true});
    await browser.windows.update(created.id,{width:720,height:520,focused:true});
    const resized=await browser.windows.get(created.id);
    let privateRejected=false;
    try {const privateWindow=await browser.windows.create({incognito:true}); await browser.windows.remove(privateWindow.id);}
    catch (_) {privateRejected=true;}
    await browser.windows.remove(created.id);
    await browser.windows.update(sender.windowId,{focused:true});
    await new Promise(resolve=>setTimeout(resolve,100));
    const remaining=await browser.windows.getAll();
    return {normalWindow:queried.type==='normal' && queried.incognito===false,
      initialBounds:queried.width===700 && queried.height===500,
      populatedTabs:queried.tabs?.length===1 && queried.tabs[0].url==='about:blank',
      resized:resized.width===720 && resized.height===520,focused:resized.focused===true,
      removed:!remaining.some(window=>window.id===created.id),privateRejected,
      createdEvent:createdEvents.includes(created.id),removedEvent:removedEvents.includes(created.id)};
  } catch (error) {return {error:String(error)};}
  finally {
    browser.windows?.onCreated?.removeListener(onCreated);
    browser.windows?.onRemoved?.removeListener(onRemoved);
    if(created) {try{await browser.windows.remove(created.id);}catch(_){}}
  }
}
browser.commands?.onCommand?.addListener(async command => {
  if (command !== 'record-fixture-command') return;
  const previous = await browser.storage.local.get('commandCount');
  await browser.storage.local.set({commandCount:(previous.commandCount || 0)+1});
});
// Permission changes/reloads can overlap content-script probes.
// Serialize this fixture's destructive lifecycle scenario, not browser events.
let probeQueue = Promise.resolve();
browser.runtime.onMessage.addListener((message, sender, reply) => {
  if (message.type !== 'probe') return false;
  probeQueue = probeQueue.then(async () => {
    const previous = await browser.storage.local.get('count');
    const count = (previous.count || 0) + 1;
    await browser.storage.local.set({count});
    const createdEvents = [], removedEvents = [], zoomEvents = [];
    const onZoom = info => zoomEvents.push(info);
    browser.tabs.onZoomChange?.addListener(onZoom);
    const onCreated = tab => createdEvents.push(tab.id);
    const onRemoved = id => removedEvents.push(id);
    browser.tabs.onCreated.addListener(onCreated);
    browser.tabs.onRemoved.addListener(onRemoved);
    let created, duplicate, tabLifecycle, selectionDiagnostics;
    let zoomDiagnostic="";
    let highlightedEvent = false;
    const onHighlighted = info => {if (created && duplicate && info.tabIds.includes(created.id) && info.tabIds.includes(duplicate.id)) highlightedEvent = true;};
    browser.tabs.onHighlighted.addListener(onHighlighted);
    try {
      created = await browser.tabs.create({url:'about:blank', active:false, pinned:true});
      const queried = await browser.tabs.get(created.id);
      duplicate = await browser.tabs.duplicate(created.id);
      const copied = await browser.tabs.get(duplicate.id);
      let zoomSet=false, zoomReset=false;
      if (typeof browser.tabs.setZoom === 'function' && typeof browser.tabs.getZoom === 'function') {
        try {
          await browser.tabs.setZoom(created.id, 1.25);
          zoomSet = await browser.tabs.getZoom(created.id) === 1.25;
          await browser.tabs.setZoom(created.id, 0);
          zoomReset = await browser.tabs.getZoom(created.id) === 1;
        } catch (error) { zoomDiagnostic=String(error); }
      } else { zoomDiagnostic="setZoom or getZoom is missing"; }

      // This system WebKit omits tabs.highlight. Exercise the supported
      // per-tab update path separately, without claiming that API exists.
      const allTabs = await browser.tabs.query({windowId:queried.windowId});
      for (const tab of allTabs) if (tab.id !== created.id && tab.id !== duplicate.id)
        await browser.tabs.update(tab.id, {highlighted:false,active:false});
      await browser.tabs.update(created.id, {highlighted:true,active:true});
      await browser.tabs.update(duplicate.id, {highlighted:true,active:false});
      const highlighted = await browser.tabs.query({windowId:queried.windowId,highlighted:true});
      const active = await browser.tabs.query({windowId:queried.windowId,active:true});
      selectionDiagnostics = {highlighted:highlighted.map(t=>({id:t.id,highlighted:t.highlighted,active:t.active})),created:created.id,duplicate:duplicate.id};
      const multiSelected = highlighted.length === 2 && highlighted.some(t=>t.id===created.id) && highlighted.some(t=>t.id===duplicate.id);
      const firstHighlightActive = active.length === 1 && active[0].id === created.id;
      await new Promise(resolve => setTimeout(resolve, 100));
      const senderTab = await browser.tabs.get(sender.tab.id);
      await browser.tabs.update(senderTab.id, {highlighted:true,active:true});
      await browser.tabs.remove([created.id, duplicate.id]);
      await browser.tabs.update(sender.tab.id, {active:true});
      // Event delivery is asynchronous relative to promise resolution.
      await new Promise(resolve => setTimeout(resolve, 100));
      tabLifecycle = {zoomSet,zoomReset,zoomEvent:zoomEvents.some(e=>e.tabId===created.id && e.oldZoomFactor===1 && e.newZoomFactor===1.25),multiSelected,firstHighlightActive,highlightedEvent,createdPinned:queried.pinned, duplicatePinned:copied.pinned,
        distinctIDs:created.id !== duplicate.id, duplicateURL:copied.url === queried.url,
        createdEvents:createdEvents.includes(created.id) && createdEvents.includes(duplicate.id),
        removedEvents:removedEvents.includes(created.id) && removedEvents.includes(duplicate.id)};
    } finally {
      browser.tabs.onZoomChange?.removeListener(onZoom);
      browser.tabs.onHighlighted.removeListener(onHighlighted);
      browser.tabs.onCreated.removeListener(onCreated);
      browser.tabs.onRemoved.removeListener(onRemoved);
      for (const tab of [created, duplicate]) if (tab) {
        try { await browser.tabs.remove(tab.id); } catch (_) {}
      }
    }
    const windowLifecycle = await probeWindows(sender.tab.id);
    const tabs = await browser.tabs.query({});
    reply({ok:true,count,windowLifecycle,tabsHighlightAvailable:typeof browser.tabs.highlight === "function",tabLifecycle,selectionDiagnostics,zoomDiagnostic,tabCount:tabs.length,senderTab:typeof sender.tab?.id === 'number'});
  }).catch(error => reply({ok:false,error:String(error)}));
  return true;
});
