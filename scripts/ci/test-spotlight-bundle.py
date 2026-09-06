#!/usr/bin/env python3
"""배포 bundle 누락/계약 drift를 거부하는 검증기의 회귀 fixture."""
import copy
import importlib.util
from pathlib import Path
import tempfile
import sys
import unittest

sys.dont_write_bytecode = True

SPEC = importlib.util.spec_from_file_location("spotlight", Path(__file__).with_name("check-spotlight-bundle.py"))
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


class BundleContractTests(unittest.TestCase):
    def setUp(self):
        self.host = CHECK.read_plist(CHECK.ROOT / "Sources/HostApp/Info.plist")
        self.info = CHECK.read_plist(CHECK.ROOT / "Sources/SpotlightImporter/Info.plist")
        self.schema = CHECK.ROOT / "Sources/SpotlightImporter/schema.xml"

    def test_source_and_built_bundle(self):
        CHECK.validate(self.info, self.schema, self.host)
        with tempfile.TemporaryDirectory() as directory:
            executable = Path(directory) / "Alhangeul"
            executable.write_bytes(b"fixture only")
            executable.chmod(0o755)
            self.info.update(CFBundleIdentifier=CHECK.IDENTIFIER, CFBundleExecutable="Alhangeul", LSMinimumSystemVersion="12.0")
            CHECK.validate(self.info, self.schema, self.host, executable)
            executable.unlink()
            with self.assertRaisesRegex(ValueError, "missing importer executable"):
                CHECK.validate(self.info, self.schema, self.host, executable)

    def test_metadata_drift_is_rejected(self):
        for key, value in [
            ("CFPlugInTypes", {}), ("CFPlugInFactories", {}),
            ("CFBundleVersion", "mismatch"), ("CFPlugInDynamicRegistration", "YES"),
            ("CFBundlePackageType", "XPC!"),
        ]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                info = copy.deepcopy(self.info)
                info[key] = value
                CHECK.validate(info, self.schema, self.host)
        self.info["CFBundleDocumentTypes"][0]["LSItemContentTypes"].pop()
        with self.assertRaisesRegex(ValueError, "UTI mismatch"):
            CHECK.validate(self.info, self.schema, self.host)

    def test_schema_mismatch_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            schema = Path(directory) / "schema.xml"
            schema.write_text(self.schema.read_text().replace("kMDItemTextContent", "unexpected"))
            with self.assertRaisesRegex(ValueError, "schema metadata mismatch"):
                CHECK.validate(self.info, schema, self.host)


if __name__ == "__main__":
    unittest.main()
