"""Pinned real-extension source build in the owned Gecko reference, not Serein."""
import hashlib
import json
import pathlib
import subprocess
import sys
import time
import zipfile


def run_formatter_reference(request, script, prefix, out, temporary):
    addon_id = 'serein-formatter-reference@serein.invalid'
    build = pathlib.Path(temporary) / 'formatter-build'
    entry = {'browser': 'Zen 1.22.2b (Gecko)', 'extension': 'JSON Formatter 0.8.0',
             'sourceCommit': '27aa9955e54757ca9919f2a3a5f9cfe8f1888272',
             'referencePreferences': {'devtools.jsonview.enabled': False},
             'manifestAdaptation': 'Added only browser_specific_settings.gecko.id for temporary Gecko installation. Original scripts, required permissions, host declarations and run_at/world entries are preserved.',
             'scope': 'Source-built real extension, not a signed store package. WebDriver inspects the actual page global through Gecko wrappedJSObject; this is reference automation only.',
             'checks': {}, 'scenarioExecuted': False}
    installed = False
    try:
        request(prefix + '/moz/context', {'context': 'chrome'})
        entry['observedJSONViewerEnabled'] = script('return Services.prefs.getBoolPref("devtools.jsonview.enabled");')
        request(prefix + '/moz/context', {'context': 'content'})
        assert entry['observedJSONViewerEnabled'] is False, 'Reference still uses the built-in JSON viewer'
        subprocess.run([sys.executable, 'script/build_json_formatter_fixture.py', str(build),
                        str(out / 'formatter-build.json')], check=True, timeout=240)
        source = build / 'extension'
        original = (source / 'manifest.json').read_bytes()
        manifest = json.loads(original)
        manifest['browser_specific_settings'] = {'gecko': {'id': addon_id}}
        entry['originalManifestSHA256'] = hashlib.sha256(original).hexdigest()
        entry['adaptedManifest'] = manifest
        package = pathlib.Path(temporary) / 'formatter.xpi'
        with zipfile.ZipFile(package, 'w') as archive:
            archive.writestr('manifest.json', json.dumps(manifest))
            for path in sorted(source.rglob('*')):
                if path.is_file() and path != source / 'manifest.json':
                    archive.write(path, str(path.relative_to(source)))
        identity = request(prefix + '/moz/addon/install', {'path': str(package), 'temporary': True})
        installed = True
        assert identity == addon_id, identity
        request(prefix + '/url', {'url': 'http://127.0.0.1:8765/formatter.json'})
        value = {}
        for _ in range(100):
            value = script('''const page=window.wrappedJSObject || window;
                const pre=document.querySelector('#jsonFormatterRaw pre');let parsed=false,rawParseError=null;
                try {parsed=JSON.parse(pre?.innerText).project==='Serein'} catch(e){rawParseError=String(e)}
                return {formatted:!!document.querySelector('#jsonFormatterParsed .entry'),
                    project:page.json?.project || null,items:page.json?.nested?.items?.length ?? null,
                    globalType:typeof page.json,rawPresent:!!pre,innerTextLength:pre?.innerText.length ?? null,
                    textContentLength:pre?.textContent.length ?? null,parsed,rawParseError};''')
            if value.get('formatted') and value.get('project') == 'Serein':
                break
            time.sleep(.1)
        entry['observation'] = value
        entry['checks'] = {'isolatedFormatsJSON': value.get('formatted') is True,
                           'rawInnerTextParses': value.get('parsed') is True,
                           'mainWorldGlobal': value.get('project') == 'Serein' and value.get('items') == 4}
        entry['scenarioExecuted'] = True
        subprocess.run(['screencapture', '-x', str(out / 'formatter-reference.png')], check=True, timeout=8)
    except Exception as error:
        entry['error'] = str(error)
    finally:
        try:
            request(prefix + '/moz/context', {'context': 'content'})
        except Exception as error:
            entry['contextCleanupError'] = str(error)
        if installed:
            try:
                request(prefix + '/moz/addon/uninstall', {'id': addon_id})
            except Exception as error:
                entry['cleanupError'] = str(error)
        (out / 'formatter-reference.json').write_text(json.dumps(entry, indent=2))
    return entry
