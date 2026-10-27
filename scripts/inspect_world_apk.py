import hashlib,json,os,re,sys,zipfile
from pathlib import Path
apk,badging,out=map(Path,sys.argv[1:])
text=badging.read_text()
if "package: name='com.tivini.livingworld'" not in text:raise SystemExit('Wrong application ID')
with zipfile.ZipFile(apk) as z:
    abis=sorted({p.split('/')[1] for p in z.namelist() if p.startswith('lib/') and p.endswith('.so')})
    if abis!=['arm64-v8a']:raise SystemExit(f'Wrong ABIs: {abis}')
    if any(p.endswith(('.litertlm','.tflite','.gguf')) for p in z.namelist()):raise SystemExit('Unexpected bundled model')
if re.search(r"uses-permission:",text):raise SystemExit('Unexpected release permission')
metadata=dict(commit=os.environ['GITHUB_SHA'],run_id=os.environ['GITHUB_RUN_ID'],applicationId='com.tivini.livingworld',abis=abis,size_bytes=apk.stat().st_size,sha256=hashlib.sha256(apk.read_bytes()).hexdigest(),hardware_tested=False,mode='rules',signing='experimental ephemeral debug certificate')
out.write_text(json.dumps(metadata,indent=2)+'\n')
print(json.dumps(metadata))
