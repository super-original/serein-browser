"""Build pinned, unmodified upstream sources for CI only; do not upload packages."""
import hashlib
import io
import json
import pathlib
import platform
import shutil
import subprocess
import sys
import tarfile
import urllib.request

SOURCES=[
 ('source','https://codeload.github.com/callumlocke/json-formatter/tar.gz/refs/tags/v0.8.0','52974fbe886c9be3ee9862cb3af28517479a2f77c2abe13e2891fcc28cdd094b'),
 ('compiler','https://registry.npmjs.org/@esbuild/darwin-arm64/-/darwin-arm64-0.25.5.tgz','61a312bcb8249d058639c405cf6378dd3107de5535a9974973c48a6dd0d2d062'),
]

def main():
    root=pathlib.Path(sys.argv[1]);evidence=pathlib.Path(sys.argv[2])
    result=dict(version='0.8.0',source_commit='27aa9955e54757ca9919f2a3a5f9cfe8f1888272',
                build_kind='Source build, not a Chrome Web Store package',compiler='esbuild 0.25.5 darwin-arm64',sources=[],success=False)
    try:
        assert platform.system()=='Darwin' and platform.machine()=='arm64'
        root.mkdir(parents=True,exist_ok=False)
        for name,url,digest in SOURCES:
            data=urllib.request.urlopen(url,timeout=60).read(16*1024*1024+1)
            assert len(data)<=16*1024*1024 and hashlib.sha256(data).hexdigest()==digest,'Source hash/size mismatch'
            result['sources'].append(dict(name=name,url=url,sha256=digest,bytes=len(data)))
            destination=root/name;destination.mkdir()
            with tarfile.open(fileobj=io.BytesIO(data),mode='r:gz') as archive:
                members=archive.getmembers()
                assert len(members)<=1000 and sum(m.size for m in members)<=64*1024*1024
                assert all((m.isfile() or m.isdir()) and not pathlib.PurePosixPath(m.name).is_absolute() and '..' not in pathlib.PurePosixPath(m.name).parts for m in members)
                archive.extractall(destination,filter='data')
        source=root/'source/json-formatter-0.8.0';src=source/'src';out=root/'extension';out.mkdir()
        compiler=root/'compiler/package/bin/esbuild'
        version=subprocess.check_output([str(compiler),'--version'],text=True,timeout=30).strip()
        assert version=='0.25.5'
        for path in src.rglob('*'):
            if path.is_file() and path.suffix not in ['.ts','.css']:
                target=out/path.relative_to(src);target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,target)
        for entry in sorted(src.rglob('*.entry.ts')):
            target=out/str(entry.relative_to(src)).replace('.entry.ts','.js');target.parent.mkdir(parents=True,exist_ok=True)
            subprocess.run([str(compiler),'--bundle',str(entry),'--outfile='+str(target),'--minify'],check=True,timeout=60)
        shutil.copyfile(source/'LICENSE',out/'LICENSE')
        assert (out/'manifest.json').read_bytes()==(src/'manifest.json').read_bytes()
        result['files']={str(p.relative_to(out)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(out.rglob('*')) if p.is_file()}
        result['success']=True
    except Exception as error:result['error']=str(error)
    evidence.write_text(json.dumps(result,indent=2)+'\n')
    return 0 if result['success'] else 1

if __name__=='__main__':sys.exit(main())
