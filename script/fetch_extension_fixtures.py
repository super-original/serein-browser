"""Download exact upstream packages for local CI testing; never upload packages."""
import concurrent.futures, hashlib, json, pathlib, urllib.request, sys

root=pathlib.Path(sys.argv[1]);root.mkdir(parents=True,exist_ok=True)
rows=json.loads(pathlib.Path('Fixtures/extension-catalog.json').read_text())
def fetch(row):
    try:
        request=urllib.request.Request(row['url'],headers={'User-Agent':'Serein-Compatibility-Audit/0.1'})
        data=urllib.request.urlopen(request,timeout=60).read(64*1024*1024+1)
        if len(data)>64*1024*1024: raise ValueError('package exceeds limit')
        if hashlib.sha256(data).hexdigest()!=row['sha256']: raise ValueError('upstream hash mismatch')
        path=root/(row['name']+'.zip');path.write_bytes(data);row['path']=str(path.resolve())
    except Exception as error: row['fetchError']=str(error)
    return row
results=list(concurrent.futures.ThreadPoolExecutor(max_workers=3).map(fetch,rows))
(root/'catalog.json').write_text(json.dumps(results,indent=2))
for row in results:print(row['name'],row.get('fetchError','downloaded and SHA-256 verified'))
