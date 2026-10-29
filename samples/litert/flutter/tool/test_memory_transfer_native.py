"""Native source policy gates only; SAF runtime/device behavior is separate."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
KOTLIN = ROOT / 'android/app/src/main/kotlin/com/google/ai/edge/examples/litert_edge_demos'


class NativeTransferPolicy(unittest.TestCase):
    def source(self):
        path = KOTLIN / 'LivingMemoryTransfer.kt'
        self.assertTrue(path.is_file(), 'Native SAF transfer implementation is missing')
        return path.read_text()

    def test_saf_only_with_both_open_and_create_documents(self):
        source = self.source()
        self.assertIn('Intent.ACTION_OPEN_DOCUMENT', source)
        self.assertIn('Intent.ACTION_CREATE_DOCUMENT', source)
        self.assertNotIn('ACTION_GET_CONTENT', source)
        self.assertNotIn('MANAGE_EXTERNAL_STORAGE', source)

    def test_database_is_streamed_with_a_size_bound_not_materialized(self):
        source = self.source()
        self.assertIn('openInputStream', source)
        self.assertIn('openOutputStream', source)
        self.assertRegex(source, r'total\s*<=\s*MAX_BACKUP_BYTES')
        self.assertNotRegex(source, r'readBytes\(|readFully\(|ByteArrayOutputStream|readAsBytes')

    def test_native_transfer_owns_a_confined_private_staging_directory(self):
        source = self.source()
        self.assertIn('activity.cacheDir', source)
        self.assertIn('living-memory-transfer', source)
        self.assertIn('canonicalFile', source)
        self.assertRegex(source, r'parentFile\s*==\s*')
        self.assertNotRegex(source, r'Log\.|println\(|printStackTrace\(')

    def test_activity_registers_dispatches_and_closes_transfer_handler(self):
        self.source()
        source = (KOTLIN / 'MainActivity.kt').read_text()
        self.assertIn('living_memory/transfer', source)
        self.assertIn('LivingMemoryTransfer(this)', source)
        self.assertRegex(source, r'transfer\?\.onActivityResult')
        self.assertRegex(source, r'transfer\?\.close\(')


if __name__ == '__main__':
    unittest.main()
