#!/usr/bin/env python3
"""UTI 누락 및 확장 간 계약 불일치 회귀."""
import copy
import importlib.util
import plistlib
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('contract', HERE / 'check-quicklook-content-types.py')
contract = importlib.util.module_from_spec(spec)
spec.loader.exec_module(contract)

def types(info):
    return info['NSExtension']['NSExtensionAttributes']['QLSupportedContentTypes']

class ContractTests(unittest.TestCase):
    def setUp(self):
        self.infos = []
        for name in ['QLExtension', 'ThumbnailExtension']:
            with (contract.ROOT / 'Sources' / name / 'Info.plist').open('rb') as stream:
                self.infos.append(plistlib.load(stream))

    def test_source_contract(self):
        contract.validate(*self.infos)

    def test_each_required_type_cannot_disappear(self):
        for index in range(2):
            for uti in contract.REQUIRED:
                with self.subTest(index=index, uti=uti):
                    infos = copy.deepcopy(self.infos)
                    types(infos[index]).remove(uti)
                    with self.assertRaisesRegex(ValueError, 'missing supported'):
                        contract.validate(*infos)

    def test_duplicate_is_rejected(self):
        types(self.infos[0]).append(types(self.infos[0])[0])
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            contract.validate(*self.infos)

    def test_extension_drift_is_rejected(self):
        types(self.infos[0]).append('example.verified.hwp')
        with self.assertRaisesRegex(ValueError, 'differ'):
            contract.validate(*self.infos)

    def test_non_string_is_rejected(self):
        types(self.infos[0]).append(1)
        with self.assertRaisesRegex(ValueError, 'string array'):
            contract.validate(*self.infos)

    def test_future_verified_alias_can_be_added_to_both(self):
        for info in self.infos:
            types(info).append('example.verified.hwp')
        contract.validate(*self.infos)

if __name__ == '__main__':
    unittest.main()
