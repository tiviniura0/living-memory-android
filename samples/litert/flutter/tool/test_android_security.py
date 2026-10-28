"""Source gates; installed/merged APK and CVE scanning are separate."""
from pathlib import Path
import unittest
import os
import xml.etree.ElementTree as ET
ROOT = Path(__file__).resolve().parents[1]
A = '{http://schemas.android.com/apk/res/android}'
T = '{http://schemas.android.com/tools}'
class AndroidSecurity(unittest.TestCase):
    def setUp(self):
        self.manifest = ET.parse(Path(os.environ.get('ANDROID_MERGED_MANIFEST', str(ROOT / 'android/app/src/main/AndroidManifest.xml')))).getroot()
        self.app = self.manifest.find('application')
    def test_private_data_excluded_from_backup(self):
        self.assertEqual(self.app.get(A + 'allowBackup'), 'false')
        self.assertEqual(self.app.get(A + 'fullBackupContent'), 'false')
        rules = ET.parse(ROOT / 'android/app/src/main/res/xml/memory_data_extraction_rules.xml').getroot()
        for section in ('cloud-backup', 'device-transfer'):
            exclusions = {(e.get('domain'), e.get('path')) for e in rules.find(section)}
            self.assertIn(('root', '.'), exclusions)
    def test_release_not_debuggable(self):
        self.assertNotEqual(self.app.get(A + 'debuggable'), 'true')
    def test_cleartext_explicitly_disabled(self):
        self.assertEqual(self.app.get(A + 'usesCleartextTraffic'), 'false')
    def test_exported_components_are_system_protected_and_no_broad_storage(self):
        for component in self.app:
            if component.get(A + 'exported') == 'true':
                if component.get(A + 'name') not in {'.MainActivity', 'com.google.ai.edge.examples.litert_edge_demos.MainActivity'}:
                    expected = {
                        'androidx.work.impl.background.systemjob.SystemJobService': ('service', 'android.permission.BIND_JOB_SERVICE'),
                        'com.bbflight.background_downloader.UIDTJobService': ('service', 'android.permission.BIND_JOB_SERVICE'),
                        'androidx.work.impl.diagnostics.DiagnosticsReceiver': ('receiver', 'android.permission.DUMP'),
                        'androidx.profileinstaller.ProfileInstallReceiver': ('receiver', 'android.permission.DUMP'),
                    }
                    self.assertIn(component.get(A + 'name'), expected)
                    self.assertEqual((component.tag, component.get(A + 'permission')), expected[component.get(A + 'name')])
                else:
                    self.assertEqual(component.tag, 'activity')
        permissions = {p.get(A + 'name') for p in self.manifest.findall('uses-permission') if p.get(T + 'node') != 'remove'}
        self.assertFalse(permissions & {'android.permission.MANAGE_EXTERNAL_STORAGE', 'android.permission.READ_EXTERNAL_STORAGE', 'android.permission.WRITE_EXTERNAL_STORAGE'})
if __name__ == '__main__':
    unittest.main()
