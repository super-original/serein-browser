"""One bounded, unmodified public WebKit build on the standard macOS 27 runner."""
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
from bounded_build import GIB, run_bounded

COMMIT='131cc0a7111b3a8c4038989d7bd5cee49c1ad7f7'
REPOSITORY='https://github.com/WebKit/WebKit.git'


def main():
    evidence=pathlib.Path('evidence/webkit-build').resolve()
    evidence.mkdir(parents=True,exist_ok=True)
    environment=os.environ.copy()
    environment.update(DEVELOPER_DIR='/Applications/Xcode_27.1.app/Contents/Developer',
                       MACOSX_DEPLOYMENT_TARGET='27.0',WK_USE_CCACHE='NO')
    def output(command):return subprocess.check_output(command,text=True,env=environment,timeout=30).strip()
    facts=dict(os=output(['sw_vers']),architecture=output(['uname','-m']),
               xcode=output(['xcodebuild','-version']),sdk=output(['xcrun','--sdk','macosx','--show-sdk-version']),
               swift=output(['xcrun','swift','--version']),memory_bytes=int(output(['sysctl','-n','hw.memsize'])),
               source_commit=COMMIT,repository=REPOSITORY,minimum_macos='27.0',compiler_jobs=2,
               per_stage_minutes=dict(fetch=10,checkout=15,build=75),
               disk_reserve_bytes=8*GIB,descendant_rss_limit_bytes=5*GIB,minimum_system_free_memory_percent=8)
    (evidence/'toolchain.json').write_text(json.dumps(facts,indent=2)+'\n')
    assert output(['sw_vers','-productVersion']).split('.')[0]=='27'
    assert facts['architecture']=='arm64' and facts['sdk']=='27.0'
    assert 'Xcode 27.1' in facts['xcode'] and '27A9269' in facts['xcode']
    root=pathlib.Path(tempfile.mkdtemp(prefix='serein-webkit-build-',dir=os.environ['RUNNER_TEMP']))
    source=root/'source';source.mkdir()
    environment['WEBKIT_OUTPUTDIR']=str(root/'products')
    (evidence/'owned-paths.json').write_text(json.dumps(dict(root=str(root),source=str(source),products=environment['WEBKIT_OUTPUTDIR']))+'\n')
    stages=[]
    def stage(name,command,seconds):
        result=run_bounded(command,cwd=source,evidence=evidence,name=name,seconds=seconds,env=environment)
        stages.append(result)
        (evidence/'stages.json').write_text(json.dumps(stages,indent=2)+'\n')
        return result['returncode']==0 and result['stop_reason'] is None
    def git(*args):subprocess.run(['git',*args],cwd=source,check=True,env=environment,timeout=30)
    if shutil.disk_usage(root).free<12*GIB:
        raise RuntimeError('Insufficient initial disk reserve for the source experiment')
    git('init','--quiet');git('remote','add','origin',REPOSITORY)
    if not stage('fetch',['git','fetch','--depth=1','--filter=blob:none','origin',COMMIT],600):return 1
    git('sparse-checkout','init','--cone')
    # Include all runtime/build sources and root files; omit large web test corpora.
    # This does not disable engine features. A missing required resource is a failure.
    git('sparse-checkout','set','Source','Tools','Configurations','resources','metadata','WebKitLibraries','WebKit.xcworkspace')
    if not stage('checkout',['git','checkout','--detach',COMMIT],900):return 1
    actual=subprocess.check_output(['git','rev-parse','HEAD'],cwd=source,text=True).strip()
    assert actual==COMMIT
    (evidence/'checkout-size.txt').write_text(output(['du','-sk',str(root)])+'\n')
    (evidence/'source-status.txt').write_text(subprocess.check_output(['git','status','--porcelain'],cwd=source,text=True))
    command=['Tools/Scripts/build-webkit','--release','--only-webkit','--xcode','-jobs','2',
             '-sdk','macosx','ARCHS=arm64','ONLY_ACTIVE_ARCH=YES','MACOSX_DEPLOYMENT_TARGET=27.0']
    succeeded=stage('build',command,4500)
    (evidence/'final-size.txt').write_text(output(['du','-sk',str(root)])+'\n')
    products=root/'products'
    frameworks=sorted({p.resolve() for p in products.rglob('WebKit.framework') if p.is_dir()}) if products.exists() else []
    audits=[]
    for framework in frameworks:
        binary=(framework/'WebKit').resolve()
        if not binary.is_file() or not binary.is_relative_to(root):
            audits.append(dict(path=str(framework),valid=False,error='No owned framework binary'))
            continue
        archs=output(['xcrun','lipo','-archs',str(binary)])
        build=output(['xcrun','vtool','-show-build',str(binary)])
        valid=archs=='arm64' and re.search(r'\bminos 27\.0\b',build) is not None and re.search(r'\bsdk 27\.0\b',build) is not None
        signature=subprocess.run(['codesign','--verify','--deep','--strict',str(framework)],capture_output=True,text=True,timeout=30)
        audits.append(dict(path=str(framework.relative_to(root)),valid=valid,architectures=archs,build_metadata=build,
                           signature_verification_returncode=signature.returncode,signature_detail=signature.stderr[-4000:]))
    (evidence/'products.json').write_text(json.dumps(dict(build_command_succeeded=succeeded,framework_audits=audits,
        scope='Compile feasibility only. No engine adoption, patch, packaging, hardened runtime validation or conformance pass follows from this experiment.'),indent=2)+'\n')
    return 0 if succeeded and audits and all(a['valid'] for a in audits) else 1

if __name__=='__main__':
    sys.exit(main())
