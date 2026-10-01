const records = new Map();
browser.runtime.onConnect.addListener(port => {
  const record = {received:[], disconnected:false, senderURL:port.sender?.url, frameId:port.sender?.frameId};
  records.set(port.name, record);
  port.onMessage.addListener(message => {
    record.received.push(message.sequence);
    port.postMessage({sequence:message.sequence, value:message.value, senderURL:record.senderURL, frameId:record.frameId});
  });
  port.onDisconnect.addListener(() => { record.disconnected=true; });
});
browser.runtime.onMessage.addListener((message, sender, reply) => {
  if(message.kind !== 'port-result') return false;
  reply(records.get(message.name) || null);
  return false;
});
