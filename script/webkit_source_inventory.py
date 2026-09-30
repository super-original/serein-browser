"""Read-only GitHub source-size inventory; does not estimate build resources."""
import argparse,datetime,json,subprocess,pathlib
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--commit',default='131cc0a7111b3a8c4038989d7bd5cee49c1ad7f7')
parser.add_argument('--output',type=pathlib.Path,required=True)
args=parser.parse_args()
count=0
repo='repos/WebKit/WebKit'
def api(path):
 global count
 count+=1
 if count>120:raise RuntimeError('Metadata request budget exceeded')
 return json.loads(subprocess.check_output(['gh','api',path],text=True))
commit=api(repo+'/commits/'+args.commit)['sha']
def measure(sha):
 tree=api(repo+'/git/trees/'+sha+'?recursive=1')
 if not tree.get('truncated'):
  blobs=[x for x in tree['tree'] if x['type']=='blob']
  return len(blobs),sum(x.get('size',0) for x in blobs)
 files=size=0
 for x in api(repo+'/git/trees/'+sha)['tree']:
  if x['type']=='tree':
   n,b=measure(x['sha']);files+=n;size+=b
  elif x['type']=='blob':files+=1;size+=x.get('size',0)
 return files,size
root=api(repo+'/git/trees/'+commit)
parts=[]
for entry in root['tree']:
 if entry['path'] in ['Source','Tools','WebKitLibraries','WebKit.xcworkspace']:
  n,b=measure(entry['sha']);parts.append({'path':entry['path'],'files':n,'blob_bytes':b})
result={'repository':'https://github.com/WebKit/WebKit','commit':commit,'measured_on':datetime.datetime.now(datetime.timezone.utc).date().isoformat(),'scope':'Git tree blob sizes for selected build-relevant directories; not checkout disk use, Git pack size, build products, peak RAM or build duration. Truncated API responses recursively expanded.','parts':parts,'metadata_requests':count}
args.output.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
