import unittest,tempfile,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
import check_world_boundaries as checker
class BoundaryTest(unittest.TestCase):
    def test_boundary_check_detects_flutter_in_core(self):
        with tempfile.TemporaryDirectory() as folder:
            p=Path(folder)/'packages/world_core/lib';p.mkdir(parents=True)
            (p/'bad.dart').write_text("import 'package:flutter/widgets.dart';")
            self.assertTrue(checker.check(folder))
    def test_boundary_check_accepts_dart_core(self):
        with tempfile.TemporaryDirectory() as folder:
            p=Path(folder)/'packages/world_core/lib';p.mkdir(parents=True)
            (p/'good.dart').write_text("import 'dart:math';")
            self.assertEqual(checker.check(folder),[])
    def test_no_personal_permissions_in_world_manifest(self):
        with tempfile.TemporaryDirectory() as folder:
            p=Path(folder)/'apps/world_observer/android/app/src/main';p.mkdir(parents=True)
            (p/'AndroidManifest.xml').write_text('<manifest><uses-permission name="camera"/></manifest>')
            self.assertTrue(checker.check(folder))
if __name__=='__main__':unittest.main()
