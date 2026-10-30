"""Inspect packaging, not execution, of the Task 1 ARM64 smoke APK."""
import hashlib
import json
from pathlib import Path
import sys
import zipfile


def inspect(apk):
    apk = Path(apk)
    library = 'lib/arm64-v8a/libgodot_android.so'
    pack = 'assets/world_godot.pck'
    with zipfile.ZipFile(apk) as archive:
        names = archive.namelist()
        abis = sorted({n.split('/')[1] for n in names if n.startswith('lib/') and n.endswith('.so')})
        if abis != ['arm64-v8a']:
            raise ValueError(f'ARM64-only APK required, found {abis}')
        if library not in names:
            raise ValueError('Official Godot library is absent')
        if 'lib/arm64-v8a/libflutter.so' not in names:
            raise ValueError('Flutter runtime is absent')
        if pack not in names:
            raise ValueError('Godot PCK is absent')
        pack_sha = hashlib.sha256(archive.read(pack)).hexdigest()
        native_sha = hashlib.sha256(archive.read(library)).hexdigest()
    with apk.open('rb') as stream:
        apk_sha = hashlib.file_digest(stream, 'sha256').hexdigest()
    return {
        'abis': abis,
        'godot_library': library,
        'godot_library_sha256': native_sha,
        'pack_sha256': pack_sha,
        'apk_sha256': apk_sha,
        'native_execution_verified': False,
    }


if __name__ == '__main__':
    Path(sys.argv[2]).write_text(json.dumps(inspect(sys.argv[1]), indent=2) + '\n')
