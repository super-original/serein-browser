browser.runtime.onMessage.addListener(async message => {
  if (message.operation !== 'roundtrip') return;
  const previous = (await browser.storage.local.get('count')).count || 0;
  await browser.storage.local.set({count:previous + 1});
  return {count:previous + 1, value:message.value, id:browser.runtime.id};
});
