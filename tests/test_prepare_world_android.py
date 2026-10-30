import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import shutil

class PrepareWorldAndroidTest(unittest.TestCase):
    def test_preserves_tracked_android_host_on_repeated_preparation(self):
        repo = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            shutil.copytree(repo / 'apps/world_observer/android', root / 'apps/world_observer/android')
            (root / 'scripts').mkdir()
            shutil.copy(repo / 'scripts/prepare_world_android.sh', root / 'scripts')
            (root / 'scripts/check_world_boundaries.py').write_text('')
            fake = root / 'bin'; fake.mkdir()
            flutter = fake / 'flutter'
            flutter.write_text('#!/bin/bash\ntarget="${@: -1}"\nmkdir -p "$target/android/app/src/main/kotlin/com/tivini/livingworld"\necho overwritten > "$target/android/app/build.gradle.kts"\necho overwritten > "$target/android/app/src/main/kotlin/com/tivini/livingworld/MainActivity.kt"\n')
            flutter.chmod(0o755)
            gradle = root / 'apps/world_observer/android/app/build.gradle.kts'
            before = gradle.read_bytes()
            env = dict(os.environ, PATH=str(fake)+os.pathsep+os.environ['PATH'])
            for _ in range(2):
                subprocess.run(['bash','scripts/prepare_world_android.sh'], cwd=root,env=env,check=True,capture_output=True)
                self.assertEqual(before,gradle.read_bytes(), 'Preparation destroyed the tracked Godot host')
