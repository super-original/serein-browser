import base64, pathlib, sys
root=pathlib.Path(sys.argv[1])
for f in sorted(root.rglob('*')):
    if f.is_file(): print('EVIDENCE_FILE',f.name,f.stat().st_size,flush=True)
    if f.suffix not in ('.png','.json','.h') and f.name != 'swiftui-interfaces.txt':continue
    print('SEREIN_FILE_BEGIN '+str(f.relative_to(root)),flush=True)
    s=base64.b64encode(f.read_bytes()).decode()
    for i in range(0,len(s),2000):print('SEREIN_BYTES '+s[i:i+2000],flush=True)
    print('SEREIN_FILE_END',flush=True)
