"""Regression tests for Android SDK apksigner output formats."""
import unittest
from pathlib import Path
from apk_signer import certificate_sha256


class SignerTest(unittest.TestCase):
    def test_actual_v2_output(self):
        output = (Path(__file__).parent / 'fixtures/apksigner-v2.txt').read_text()
        self.assertEqual(certificate_sha256(output), '924b228ceeb274bb575755ffba599e165121c6998f82f491090284b6c2f0eccc')

    def test_legacy_output(self):
        self.assertEqual(certificate_sha256('Signer #1 certificate SHA-256 digest: ' + 'a' * 64), 'a' * 64)

    def test_public_key_is_not_a_certificate(self):
        with self.assertRaises(ValueError):
            certificate_sha256('V2 Signer: public key SHA-256 digest: ' + 'a' * 64)

    def test_missing_short_or_oversized_digest(self):
        for output in ['', 'V2 Signer: certificate SHA-256 digest: ' + 'a' * 63, 'V2 Signer: certificate SHA-256 digest: ' + 'a' * 65]:
            with self.subTest(output=output), self.assertRaises(ValueError):
                certificate_sha256(output)

    def test_multiple_distinct_signers_are_rejected(self):
        output = 'Signer #1 certificate SHA-256 digest: ' + 'a' * 64 + '\nSigner #2 certificate SHA-256 digest: ' + 'b' * 64
        with self.assertRaises(ValueError):
            certificate_sha256(output)
