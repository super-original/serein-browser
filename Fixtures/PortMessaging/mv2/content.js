(async () => {
  if (!location.search.includes('port-lifecycle=')) return;
  const name = 'serein-port-'+new URLSearchParams(location.search).get('port-lifecycle');
  const echoes=[];
  const port=browser.runtime.connect({name});
  let failure=null;
  port.onDisconnect.addListener(() => {
    document.documentElement.dataset.portDisconnected='true';
    if(browser.runtime.lastError) failure=browser.runtime.lastError.message;
  });
  port.onMessage.addListener(message => { echoes.push(message); });
  for(let sequence=0;sequence<3;sequence++) port.postMessage({sequence,value:{text:'message '+sequence,unicode:'雪',items:[null,true,sequence]}});
  for(let attempt=0;attempt<60 && echoes.length<3;attempt++) await new Promise(resolve=>setTimeout(resolve,50));
  document.documentElement.dataset.portEchoes=JSON.stringify({echoes,failure});
  if(name.endsWith('disable')) return; // Leave the live port for native disable.
  port.disconnect();
  let record=null;
  for(let attempt=0;attempt<60;attempt++) {
    record=await browser.runtime.sendMessage({kind:'port-result',name});
    if(record?.disconnected) break;
    await new Promise(resolve=>setTimeout(resolve,50));
  }
  document.documentElement.dataset.portResult=JSON.stringify({echoes,record,failure});
})().catch(error=>{document.documentElement.dataset.portError=String(error);});
