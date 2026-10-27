"""Check the portable packages and the distinct Android release manifest."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

def check(root):
    root=Path(root)
    findings=[]
    forbidden=re.compile(r"(?:import|export)\s+['\"](?:dart:io|package:(?:flutter|sqlite\w*|world_persistence|http|\w*litert\w*)[/:])")
    for package in ('world_contracts','world_core','agent_runtime'):
        for source in (root/'packages'/package/'lib').rglob('*.dart'):
            if forbidden.search(source.read_text()):
                findings.append(f'{source.relative_to(root)}: forbidden platform import')
        pubspec=root/'packages'/package/'pubspec.yaml'
        if pubspec.exists() and re.search(r'^\s+(?:flutter|sqlite\w*|http|\w*litert\w*):',pubspec.read_text(),re.M):
            findings.append(f'{pubspec.relative_to(root)}: forbidden platform dependency')
    manifest=root/'apps/world_observer/android/app/src/main/AndroidManifest.xml'
    if manifest.exists():
        try:
            if any(node.tag.startswith('uses-permission') for node in ET.fromstring(manifest.read_text())):
                findings.append('Android release manifest requests permissions')
        except ET.ParseError:
            findings.append('Android release manifest is malformed')
    for source in (root/'apps/world_observer/lib').rglob('*.dart'):
        if re.search(r"(?:import|export)\s+['\"][^'\"]*(?:samples/litert|living_memory/)",source.read_text()):
            findings.append(f'{source.relative_to(root)}: private memory dependency')
    return findings

if __name__=='__main__':
    import sys
    findings=check(sys.argv[1] if len(sys.argv)>1 else '.')
    print('\n'.join(findings) if findings else 'World boundaries: OK')
    sys.exit(bool(findings))
