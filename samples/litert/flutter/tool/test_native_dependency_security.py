import unittest
from audit_native_dependencies import resolved_packages, vulnerable_packages

class NativeDependencies(unittest.TestCase):
    def test_resolved_version_replaces_requested_version(self):
        text = '+--- com.google.guava:guava:33.5.0-android -> 33.7.2-android (*)\n\\--- com.squareup.okhttp3:okhttp:4.9.0 -> 4.9.2'
        self.assertEqual(resolved_packages(text)['com.google.guava:guava'], {'33.7.2-android'})
        self.assertEqual(vulnerable_packages(text), [])
    def test_affected_guava_and_okhttp_are_rejected(self):
        text = '+--- com.google.guava:guava:33.5.0-android\n\\--- com.squareup.okhttp3:okhttp:4.9.0'
        self.assertEqual(len(vulnerable_packages(text)), 2)
    def test_missing_security_relevant_dependency_fails_closed(self):
        with self.assertRaises(ValueError): vulnerable_packages('+--- project :app')

if __name__ == '__main__': unittest.main()
