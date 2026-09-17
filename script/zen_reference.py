"""Capture one pinned, unmodified Zen build. Failures remain failures in manifest."""
import base64, json, time, urllib.request, urllib.error, subprocess, pathlib, traceback
out = pathlib.Path('evidence/zen'); results=[]
def request(path, data=None, method=None):
    req=urllib.request.Request('http://127.0.0.1:4444'+path, data=None if data is None else json.dumps(data).encode(), headers={'Content-Type':'application/json'},method=method)
    try:
        value=json.load(urllib.request.urlopen(req,timeout=80))['value']
    except urllib.error.HTTPError as e: raise RuntimeError(e.read().decode())
    if isinstance(value,dict) and 'error' in value: raise RuntimeError(value)
    return value
for _ in range(40):
    try: request('/status'); break
    except Exception: time.sleep(.25)
session=request('/session',{'capabilities':{'alwaysMatch':{'browserName':'firefox','moz:firefoxOptions':{'binary':'/tmp/Zen.app/Contents/MacOS/zen','prefs':{'zen.welcome-screen.seen':True,'browser.shell.checkDefaultBrowser':False,'browser.startup.homepage_override.mstone':'ignore','zen.view.use-single-toolbar':True,'zen.view.sidebar-expanded':True,'zen.view.compact.enable-at-startup':False,'layout.css.prefers-color-scheme.content-override':1}}}}})
sid=session['sessionId']; prefix='/session/'+sid
def js(code): return request(prefix+'/execute/sync',{'script':code,'args':[]})
def snap(name,code=''):
    try:
        if code: js(code)
        time.sleep(1.2)
        subprocess.run(['screencapture','-x',str(out/(name+'.png'))],check=True)
        geometry=js('return {width:outerWidth,height:outerHeight,scale:devicePixelRatio,sidebar:document.getElementById("navigator-toolbox").getBoundingClientRect().toJSON(),tabs:[...gBrowser.tabs].map(t=>({label:t.label,pinned:t.pinned,essential:t.hasAttribute("zen-essential"),rect:t.getBoundingClientRect().toJSON()}))};')
        results.append({'name':name,'status':'captured','geometry':geometry})
    except Exception as e: results.append({'name':name,'status':'failed','error':str(e)});print(name,str(e),flush=True)
try:
    request(prefix+'/window/rect',{'width':1000,'height':700,'x':10,'y':40})
    request(prefix+'/url',{'url':'http://127.0.0.1:8765/index.html'})
    request(prefix+'/moz/context',{'context':'chrome'})
    time.sleep(3)
    snap('01-light-expanded','Services.prefs.setIntPref("ui.systemUsesDarkTheme",0);')
    snap('02-dark-expanded','Services.prefs.setIntPref("ui.systemUsesDarkTheme",1);')
    snap('03-essentials','Services.prefs.setIntPref("ui.systemUsesDarkTheme",0);gZenPinnedTabManager.addToEssentials(gBrowser.selectedTab);gBrowser.selectedTab=gBrowser.addTab("http://127.0.0.1:8765/second.html",{triggeringPrincipal:Services.scriptSecurityManager.getSystemPrincipal()});')
    snap('04-pinned-and-normal','gBrowser.pinTab(gBrowser.selectedTab);gBrowser.selectedTab=gBrowser.addTab("http://127.0.0.1:8765/index.html",{triggeringPrincipal:Services.scriptSecurityManager.getSystemPrincipal()});')
    snap('05-address-focused','gURLBar.focus();gURLBar.select();')
    snap('06-tab-context','gURLBar.blur();document.getElementById("tabContextMenu").openPopup(gBrowser.selectedTab,"after_start",0,0,true,false);')
    js('document.getElementById("tabContextMenu").hidePopup();gZenWorkspaces.createAndSaveWorkspace("Research");')
    snap('07-workspace-research')
    snap('08-workspace-switch','gZenWorkspaces.changeWorkspaceWithID(gZenWorkspaces.getWorkspaces()[0].uuid);')
    snap('09-split','const a=gBrowser.selectedTab;const b=gBrowser.addTab("http://127.0.0.1:8765/second.html",{triggeringPrincipal:Services.scriptSecurityManager.getSystemPrincipal()});gZenViewSplitter.splitTabs([a,b]);')
    snap('10-compact-hidden','gZenCompactModeManager.preference=true;')
    snap('11-compact-revealed','gZenCompactModeManager.toggleSidebar();')
    snap('12-collapsed','gZenCompactModeManager.preference=false;Services.prefs.setBoolPref("zen.view.sidebar-expanded",false);')
    snap('13-settings','Services.prefs.setBoolPref("zen.view.sidebar-expanded",true);gBrowser.selectedTab=gBrowser.addTab("about:preferences",{triggeringPrincipal:Services.scriptSecurityManager.getSystemPrincipal()});')
    snap('14-network-error','gBrowser.selectedTab=gBrowser.addTab("http://127.0.0.1:1/",{triggeringPrincipal:Services.scriptSecurityManager.getSystemPrincipal()});')
finally:
    (out/'manifest.json').write_text(json.dumps({'zen':'1.22.2b','theme':'Built-in default, no mods','requestedWindow':[1000,700],'results':results},indent=2))
    request(prefix,method='DELETE')
for f in sorted(out.glob('*.png')):
    print('SEREIN_FILE_BEGIN '+f.name,flush=True)
    print(base64.b64encode(f.read_bytes()).decode(),flush=True)
    print('SEREIN_FILE_END',flush=True)
print(json.dumps(results,indent=2))
if sum(x['status']=='captured' for x in results)<12: raise SystemExit('Fewer than twelve successful captures')
