import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location('inspect_godot', Path(__file__).resolve().parents[1] / 'scripts/inspect_world_godot_apk.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class GodotApkPackagingTest(unittest.TestCase):
    def apk(self, root, entries):
        path = Path(root) / 'test.apk'
        with zipfile.ZipFile(path, 'w') as z:
            for name in entries: z.writestr(name, b'unit-test-placeholder')
        return path
    def test_reports_arm64_native_library_and_pack_hashes(self):
        with tempfile.TemporaryDirectory() as td:
            data = module.inspect(self.apk(td, ['lib/arm64-v8a/libgodot_android.so','lib/arm64-v8a/libflutter.so','assets/world_godot.pck']))
            self.assertEqual(['arm64-v8a'],data.get('abis'))
            self.assertEqual('lib/arm64-v8a/libgodot_android.so',data.get('godot_library'))
            self.assertEqual(64,len(data.get('pack_sha256','')))
            self.assertIs(False,data.get('native_execution_verified'))
    def test_rejects_missing_pack(self):
        with tempfile.TemporaryDirectory() as td:
            with self.assertRaisesRegex(ValueError,'PCK'):
                module.inspect(self.apk(td,['lib/arm64-v8a/libgodot_android.so','lib/arm64-v8a/libflutter.so']))
    def test_rejects_additional_architecture(self):
        with tempfile.TemporaryDirectory() as td:
            with self.assertRaisesRegex(ValueError,'ARM64'):
                module.inspect(self.apk(td,['lib/x86_64/libgodot_android.so','assets/world_godot.pck']))
    def test_rejects_missing_official_godot_library(self):
        with tempfile.TemporaryDirectory() as td:
            with self.assertRaisesRegex(ValueError,'Godot'):
                module.inspect(self.apk(td,['lib/arm64-v8a/libflutter.so','assets/world_godot.pck']))
