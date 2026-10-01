"""Run original downloads fixture in the already pinned, owned Gecko reference."""
import hashlib
import json
import pathlib
import time
import zipfile


def run_download_reference(request, script, prefix, out, temporary, version, download_directory):
    addon_id=f'serein-download-reference-mv{version}@serein.invalid'
    source=pathlib.Path('Fixtures/DownloadAPI')
    manifest=dict(manifest_version=version,name='Serein download API reference',version='1.0',
                  permissions=['downloads'],browser_specific_settings={'gecko':{'id':addon_id}},
                  background={'scripts':['background.js'],'persistent':version==2},
                  content_scripts=[{'matches':['http://127.0.0.1/*'],'js':['content.js'],'run_at':'document_idle'}])
    if version==3:manifest['host_permissions']=['http://127.0.0.1/*']
    else:manifest['permissions'].append('http://127.0.0.1/*')
    entry=dict(variant=f'mv{version}',browser='Zen 1.22.2b (Gecko)',fixtureVersion='1.0',
               manifest=manifest,scriptSHA256={name:hashlib.sha256((source/name).read_bytes()).hexdigest() for name in ['background.js','content.js']},
               scope='Real Gecko downloads behavior only. Not a Serein pass or universal Chrome/Firefox compatibility result.')
    package=pathlib.Path(temporary)/f'downloads-mv{version}.xpi'
    with zipfile.ZipFile(package,'w') as archive:
        archive.writestr('manifest.json',json.dumps(manifest))
        for name in ['background.js','content.js']:archive.write(source/name,name)
    try:
        installed=request(prefix+'/moz/addon/install',{'path':str(package),'temporary':True})
        assert installed==addon_id,installed
        url=f'http://127.0.0.1:8765/index.html?downloads-reference=mv{version}'
        request(prefix+'/url',{'url':url})
        for _ in range(450):
            value=script('return document.documentElement.dataset.downloadReference || null')
            if value:
                entry['result']=json.loads(value)
                break
            time.sleep(0.1)
        if 'result' not in entry:entry['error']='Download fixture did not finish within 45 seconds'
        entry['scenarioExecuted']='result' in entry and not entry['result'].get('error')
        if 'result' in entry:
            removed=entry['result'].get('observations',{}).get('removedFilename')
            if removed:
                path=pathlib.Path(removed).resolve()
                owned=path.is_relative_to(pathlib.Path(download_directory).resolve())
                entry['result']['checks']['removeFileActuallyRemoved']=owned and not path.exists()
                entry['result']['observations']['removedPathIsOwned']=owned
            entry['passingChecks']=sum(value is True for value in entry['result'].get('checks',{}).values())
            entry['totalChecks']=len(entry['result'].get('checks',{}))
    except Exception as error:
        entry.update(error=str(error),scenarioExecuted=False)
    finally:
        try:request(prefix+'/moz/addon/uninstall',{'id':addon_id})
        except Exception as error:entry['cleanupError']=str(error)
        (out/f'downloads-mv{version}.json').write_text(json.dumps(entry,indent=2))
    return entry
