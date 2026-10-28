"""Gate known vulnerable resolved Maven versions; not a complete CVE scanner.

References: google/guava GHSA-xxph-c9ww-hj94 and GHSA-3cqm-mf7h-prrj.
"""
import json
from pathlib import Path
import re
import sys

FLOORS = {'com.google.guava:guava': (33, 7, 2), 'com.squareup.okhttp3:okhttp': (4, 9, 2)}

def resolved_packages(text):
    packages = {}
    for line in text.splitlines():
        match = re.search(r'([\w.-]+):([\w.-]+):([^\s]+)(?: -> ([^\s]+))?', line)
        if match:
            group, artifact, requested, resolved = match.groups()
            version = resolved or requested
            if re.match(r'^\d', version):
                packages.setdefault(f'{group}:{artifact}', set()).add(version)
    return packages

def vulnerable_packages(text):
    packages = resolved_packages(text)
    findings = []
    for name, minimum in FLOORS.items():
        if name not in packages:
            raise ValueError(f'Missing resolved dependency: {name}')
        for version in packages[name]:
            numbers = re.match(r'^(\d+)\.(\d+)\.(\d+)(?:-|$)', version)
            if numbers is None or tuple(map(int, numbers.groups())) < minimum:
                findings.append({'package': name, 'resolved': version, 'minimum': '.'.join(map(str, minimum))})
    return findings

if __name__ == '__main__':
    text = Path(sys.argv[1]).read_text()
    findings = vulnerable_packages(text)
    print(json.dumps({'findings': findings, 'resolved_security_dependencies': {k: sorted(v) for k, v in resolved_packages(text).items() if k in FLOORS}}, indent=2))
    sys.exit(bool(findings))
