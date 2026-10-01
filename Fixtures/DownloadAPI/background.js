// Original controlled conformance fixture. Runs against the real browser API.
// It only downloads the fixed loopback file into the runner's temporary folder.
const api = globalThis.browser || globalThis.chrome;
api.runtime.onMessage.addListener((message, sender, reply) => {
  if (message.type !== 'download-api-reference') return false;
  (async () => {
    const events = [];
    const created = item => events.push({type:'created',id:item.id});
    const changed = delta => events.push({type:'changed',...delta});
    const erased = id => events.push({type:'erased',id});
    api.downloads.onCreated.addListener(created);
    api.downloads.onChanged.addListener(changed);
    api.downloads.onErased.addListener(erased);
    const checks = {}, observations = {}, ids = [];
    const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
    try {
      for (const name of ['Alpha.txt','Beta.txt','alpha-two.txt']) {
        const id = await api.downloads.download({url:'http://127.0.0.1:8765/download.txt?reference='+name,filename:name,saveAs:false});
        ids.push(id);
        for (let i=0;i<100;i++) {
          const [item] = await api.downloads.search({id});
          if (item?.state === 'complete') break;
          if (item?.state === 'interrupted') throw Error('Fixture download interrupted: '+item.error);
          await sleep(50);
        }
      }
      const own = items => items.filter(item => ids.includes(item.id));
      // Chrome rejects id sorting although Gecko accepts it. Keep that exact
      // observation, then exercise portable ordering without aborting the suite.
      try {observations.idOrder = own(await api.downloads.search({orderBy:['id']})).map(item=>item.id);}
      catch (error) {observations.idOrderError = String(error);}
      const all = own(await api.downloads.search({orderBy:['startTime']}));
      checks.completed = all.length === 3 && all.every(item => item.state === 'complete');
      checks.distinctNumericIDs = new Set(ids).size === 3 && ids.every(Number.isSafeInteger);
      observations.positiveAndNegativeIDs = own(await api.downloads.search({query:['alpha','-two']})).map(item => item.id);
      observations.positiveOnlyIDs = own(await api.downloads.search({query:['alpha']})).map(item => item.id);
      observations.negativeOnlyIDs = own(await api.downloads.search({query:['-two']})).map(item => item.id);
      checks.positiveAndNegative = JSON.stringify(observations.positiveAndNegativeIDs) === JSON.stringify([ids[0]]);
      checks.caseInsensitiveTerms = own(await api.downloads.search({query:['ALPHA']})).length === 2;
      checks.descendingOrder = JSON.stringify(own(await api.downloads.search({orderBy:['-startTime']})).map(item => item.id)) === JSON.stringify([...ids].reverse());
      checks.limitOne = (await api.downloads.search({query:['reference='],limit:1})).length === 1;
      checks.limitZero = own(await api.downloads.search({limit:0})).length === 3;
      checks.missingID = (await api.downloads.search({id:2147483647})).length === 0;
      async function rejection(query) {try {await api.downloads.search(query);return false;} catch (_) {return true;}}
      checks.invalidRegex = await rejection({filenameRegex:'['});
      checks.invalidSort = await rejection({orderBy:['notAField']});
      if (all[0]) {
        const first = all[0];
        observations.items = all;
        observations.startedAfterExact = own(await api.downloads.search({startedAfter:first.startTime})).map(item=>item.id);
        observations.endedBeforeEpoch = own(await api.downloads.search({endedBefore:'1970-01-01T00:00:00.000Z'})).map(item=>item.id);
        observations.filenameUppercase = own(await api.downloads.search({filename:first.filename.toUpperCase()})).map(item=>item.id);
        observations.unknownTotalBytes = own(await api.downloads.search({totalBytes:-1})).map(item=>item.id);
        observations.removedFilename = first.filename;
        checks.removeFile = false;
        await api.downloads.removeFile(first.id);
        for (let i=0;i<40;i++) {
          const [removed] = await api.downloads.search({id:first.id});
          if (removed?.exists === false) {checks.removeFile = true;break;}
          await sleep(100);
        }
        const removedIDs = await api.downloads.erase({id:first.id});
        checks.eraseReturnsID = JSON.stringify(removedIDs) === JSON.stringify([first.id]);
        checks.eraseRemovesHistory = (await api.downloads.search({id:first.id})).length === 0;
      }
      checks.createdBeforeComplete = ids.every(id => {
        const start = events.findIndex(event=>event.type==='created' && event.id===id);
        const complete = events.findIndex(event=>event.type==='changed' && event.id===id && event.state?.current==='complete');
        return start>=0 && complete>start;
      });
      checks.eraseEventBeforeReply = events.some(event=>event.type==='erased' && event.id===ids[0]);
      reply({checks,observations,events});
    } catch (error) {reply({checks,observations,events,error:String(error)});}
    finally {
      api.downloads.onCreated.removeListener(created);
      api.downloads.onChanged.removeListener(changed);
      api.downloads.onErased.removeListener(erased);
    }
  })();
  return true;
});
