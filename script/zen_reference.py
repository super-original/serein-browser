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
def snap(name,code='',key=None):
    try:
        if code: js(code)
        if key:
            pid=int(session['capabilities']['moz:processID'])
            source=f'tell application "System Events" to tell (first application process whose unix id is {pid})\nset frontmost to true\nkeystroke "{key}" using {{command down, option down}}\nend tell'
            subprocess.run(['osascript','-e',source],check=True,timeout=10)
        time.sleep(1.2)
        subprocess.run(['screencapture','-x',str(out/(name+'.png'))],check=True)
        geometry=js('return {width:outerWidth,height:outerHeight,scale:devicePixelRatio,sidebar:document.getElementById("navigator-toolbox").getBoundingClientRect().toJSON(),tabs:[...gBrowser.tabs].map(t=>({label:t.label,pinned:t.pinned,multiselected:!!t.multiselected,selected:!!t.selected,essential:t.hasAttribute("zen-essential"),rect:t.getBoundingClientRect().toJSON()}))};')
        if name in ['16-three-pane-grid','17-four-pane-addition','18-four-pane-grid','24-split-rows-keyboard','25-split-columns-keyboard']:
            geometry['splitPanes']=js('return window.referenceGridTabs.filter(t=>t.splitView).map(t=>({label:t.label,rect:t.linkedBrowser.getBoundingClientRect().toJSON()}));')
            expected=3 if name=='16-three-pane-grid' else 4
            if len(geometry['splitPanes'])!=expected or any(p['rect']['width']<=0 or p['rect']['height']<=0 for p in geometry['splitPanes']): raise RuntimeError('Incorrect visible split pane count or geometry')
            panes=[p['rect'] for p in geometry['splitPanes']]
            if name=='24-split-rows-keyboard' and not all(abs(a['x']-b['x'])<2 and a['bottom']<b['top'] for a,b in zip(panes,panes[1:])): raise RuntimeError('Command-Option-H did not produce rows')
            if name=='25-split-columns-keyboard' and not all(abs(a['y']-b['y'])<2 and a['right']<b['left'] for a,b in zip(panes,panes[1:])): raise RuntimeError('Command-Option-V did not produce columns')
        if name in ['20-folder-expanded','21-folder-collapsed','22-folder-nested','23-folder-context']:
            geometry['folders']=js('return [...document.querySelectorAll("zen-folder")].map(f=>({label:f.label,collapsed:f.collapsed,parent:f.group?.label||null,rect:f.getBoundingClientRect().toJSON(),labelRect:f.labelElement.getBoundingClientRect().toJSON(),items:f.tabs.map(t=>({label:t.label,pinned:t.pinned,empty:t.hasAttribute("zen-empty-tab"),rect:t.getBoundingClientRect().toJSON()}))}));')
            relevant=[f for f in geometry['folders'] if f['label']=='Research notes']
            if len(relevant)!=1 or relevant[0]['labelRect']['width']<=0: raise RuntimeError('Folder label missing or hidden')
            if name=='21-folder-collapsed' and not relevant[0]['collapsed']: raise RuntimeError('Folder did not collapse')
            if name=='22-folder-nested' and not any(f['parent']=='Research notes' for f in geometry['folders']): raise RuntimeError('Nested folder has no parent')
        if name=='19-glance':
            geometry['glance']=js('return [...document.querySelectorAll(".zen-glance-overlay .browserContainer, .zen-glance-overlay .zen-glance-sidebar-container")].map(e=>({className:e.className,rect:e.getBoundingClientRect().toJSON()}));')
            if len(geometry['glance'])<2 or any(p['rect']['width']<=0 or p['rect']['height']<=0 for p in geometry['glance']): raise RuntimeError('Glance overlay or controls are not visible')
        if name=='15-tab-multiselection' and sum(t.get('multiselected',False) for t in geometry['tabs'])<2: raise RuntimeError('Fewer than two tabs are actually multiselected')
        results.append({'name':name,'status':'captured','geometry':geometry})
    except Exception as e: results.append({'name':name,'status':'failed','error':str(e)});print(name,str(e),flush=True)
try:
    request(prefix+'/window/rect',{'width':1000,'height':700,'x':10,'y':40})
    request(prefix+'/url',{'url':'http://127.0.0.1:8765/index.html'})
    request(prefix+'/moz/context',{'context':'chrome'})
    time.sleep(3)
    dismiss = subprocess.run(['osascript','-e', 'tell application "System Events" to tell process "UserNotificationCenter" to click button "Don’t Allow" of window 1'],capture_output=True,text=True)
    print('Dismiss local-network dialog:',dismiss.returncode,dismiss.stdout,dismiss.stderr,flush=True)
    subprocess.run(['osascript','-e','tell application "Zen" to activate'],check=True)
    js('gBrowser.selectedTab=gBrowser.addTab("http://127.0.0.1:8765/index.html",{triggeringPrincipal:Services.scriptSecurityManager.getSystemPrincipal()});')
    time.sleep(2)
    snap('01-light-expanded','Services.prefs.setIntPref("ui.systemUsesDarkTheme",0);')
    snap('02-dark-expanded','Services.prefs.setIntPref("ui.systemUsesDarkTheme",1);')
    snap('03-essentials','Services.prefs.setIntPref("ui.systemUsesDarkTheme",0);gZenPinnedTabManager.addToEssentials(gBrowser.selectedTab);gBrowser.selectedTab=gBrowser.addTab("http://127.0.0.1:8765/second.html",{triggeringPrincipal:Services.scriptSecurityManager.getSystemPrincipal()});')
    snap('04-pinned-and-normal','gBrowser.pinTab(gBrowser.selectedTab);gBrowser.selectedTab=gBrowser.addTab("http://127.0.0.1:8765/index.html",{triggeringPrincipal:Services.scriptSecurityManager.getSystemPrincipal()});')
    snap('15-tab-multiselection','gBrowser.addToMultiSelectedTabs(gBrowser.selectedTab);gBrowser.addToMultiSelectedTabs([...gBrowser.tabs].find(t=>t.pinned&&!t.hasAttribute("zen-essential")));')
    js('gBrowser.clearMultiSelectedTabs();')
    snap('05-address-focused','gURLBar.focus();gURLBar.select();')
    snap('06-tab-context','gURLBar.blur();document.getElementById("tabContextMenu").openPopup(gBrowser.selectedTab,"after_start",0,0,true,false);')
    js('document.getElementById("tabContextMenu").hidePopup();gZenWorkspaces.createAndSaveWorkspace("Research");')
    snap('07-workspace-research')
    snap('08-workspace-switch','gZenWorkspaces.changeWorkspaceWithID(gZenWorkspaces.getWorkspaces()[0].uuid);')
    js('window.referenceSplitA=gBrowser.addTab("http://127.0.0.1:8765/index.html",{triggeringPrincipal:Services.scriptSecurityManager.getSystemPrincipal()});gBrowser.selectedTab=window.referenceSplitA;window.referenceSplitB=gBrowser.addTab("http://127.0.0.1:8765/second.html",{triggeringPrincipal:Services.scriptSecurityManager.getSystemPrincipal()});')
    time.sleep(2)
    snap('09-split','gBrowser.showTab(window.referenceSplitA);gBrowser.showTab(window.referenceSplitB);gZenViewSplitter.splitTabs([window.referenceSplitA,window.referenceSplitB],"grid");')
    js('gZenCompactModeManager.preference=true;gURLBar.blur();')
    request(prefix+'/actions',{'actions':[{'type':'pointer','id':'mouse','parameters':{'pointerType':'mouse'},'actions':[{'type':'pointerMove','duration':100,'x':800,'y':400}]}]})
    time.sleep(3)
    snap('10-compact-hidden','gZenCompactModeManager.sidebar.removeAttribute("zen-user-show");gZenCompactModeManager._clearAllHoverStates();')
    snap('11-compact-revealed','gZenCompactModeManager.toggleSidebar();')
    snap('12-collapsed','gZenCompactModeManager.preference=false;Services.prefs.setBoolPref("zen.view.sidebar-expanded",false);')
    snap('13-settings','Services.prefs.setBoolPref("zen.view.sidebar-expanded",true);gBrowser.selectedTab=gBrowser.addTab("about:preferences",{triggeringPrincipal:Services.scriptSecurityManager.getSystemPrincipal()});')
    snap('14-network-error','gBrowser.selectedTab=gBrowser.addTab("http://127.0.0.1:1/",{triggeringPrincipal:Services.scriptSecurityManager.getSystemPrincipal()});')
    js('window.referenceGridTabs=[0,1,2,3].map(i=>gBrowser.addTab("http://127.0.0.1:8765/"+(i%2 ? "second.html" : "index.html")+"?grid="+i,{triggeringPrincipal:Services.scriptSecurityManager.getSystemPrincipal()}));gBrowser.selectedTab=window.referenceGridTabs[0];')
    time.sleep(2)
    snap('16-three-pane-grid','gZenViewSplitter.splitTabs(window.referenceGridTabs.slice(0,3),"grid");')
    snap('17-four-pane-addition','gZenViewSplitter.splitTabs(window.referenceGridTabs,"grid");')
    snap('18-four-pane-grid','gZenViewSplitter.unsplitCurrentView();gZenViewSplitter.splitTabs(window.referenceGridTabs,"grid");')
    snap('24-split-rows-keyboard',key='h')
    snap('25-split-columns-keyboard',key='v')
    snap('19-glance','gZenViewSplitter.unsplitCurrentView();gBrowser.selectedTab=window.referenceGridTabs[0];gZenGlanceManager.openGlance({},window.referenceGridTabs[1]);')
    js('gZenGlanceManager.closeGlance({noAnimation:true});gZenWorkspaces.createAndSaveWorkspace("Folder reference");')
    time.sleep(2)
    js('window.referenceFolderTabs=["index.html","second.html"].map(page=>gBrowser.addTab("http://127.0.0.1:8765/"+page,{triggeringPrincipal:Services.scriptSecurityManager.getSystemPrincipal()}));gBrowser.selectedTab=window.referenceFolderTabs[0];window.referenceFolder=gZenFolders.createFolder(window.referenceFolderTabs,{renameFolder:false,label:"Research notes"});')
    time.sleep(2)
    snap('20-folder-expanded')
    snap('21-folder-collapsed','window.referenceFolder.labelElement.click();')
    snap('22-folder-nested','window.referenceFolder.collapsed=false;window.referenceSubfolder=gZenFolders.createFolder([],{renameFolder:false,label:"Reading list"});window.referenceFolder.tabs[0].after(window.referenceSubfolder);')
    snap('23-folder-context','document.getElementById("zenFolderActions").openPopup(window.referenceFolder.labelElement,"after_start",0,0,true,false);')
finally:
    (out/'manifest.json').write_text(json.dumps({'zen':'1.22.2b','theme':'Built-in default, no mods','requestedWindow':[1000,700],'results':results},indent=2))
    request(prefix,method='DELETE')
print(json.dumps(results,indent=2))
if not any(x['name']=='15-tab-multiselection' and x['status']=='captured' for x in results): raise SystemExit('Multiselection reference did not capture')
if sum(x['status']=='captured' for x in results)<12: raise SystemExit('Fewer than twelve successful captures')

if not all(any(x['name']==name and x['status']=='captured' for x in results) for name in ['16-three-pane-grid','17-four-pane-addition','18-four-pane-grid']): raise SystemExit('Grid reference capture failed')

if not any(x["name"]=="19-glance" and x["status"]=="captured" for x in results): raise SystemExit("Glance reference capture failed")

if not all(any(x['name']==name and x['status']=='captured' for x in results) for name in ['20-folder-expanded','21-folder-collapsed','22-folder-nested','23-folder-context']): raise SystemExit('Folder reference capture failed')

if not all(any(x['name']==name and x['status']=='captured' for x in results) for name in ['24-split-rows-keyboard','25-split-columns-keyboard']): raise SystemExit('Native arrangement shortcut references failed')
