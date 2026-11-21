#!/usr/bin/env python3
"""Quick Look/Thumbnail의 검증된 HWP/HWPX UTI 계약을 검사한다."""
import argparse
import plistlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REQUIRED = {
    'com.postmelee.alhangeul.hwp', 'com.postmelee.alhangeul.hwpx',
    'net.golbin.hop.hwp', 'net.golbin.hop.hwpx',
    'com.hancom.hwp', 'com.hancom.hwpx',
    'com.haansoft.hancomofficeviewer.mac.hwp',
    'com.haansoft.hancomofficeviewer.mac.hwpx',
    'org.libreoffice.hwp-document',
    # HWPX 식별자는 실제 등록 근거 확보 전까지 추정하지 않는다.
    'com.infraware.polarisofficeservice.hwp',
}

def validate(preview, thumbnail):
    lists = []
    for name, info in [('Preview', preview), ('Thumbnail', thumbnail)]:
        types = info['NSExtension']['NSExtensionAttributes']['QLSupportedContentTypes']
        if not isinstance(types, list) or not all(isinstance(t, str) for t in types):
            raise ValueError(f'{name}: content types must be a string array')
        if len(types) != len(set(types)):
            raise ValueError(f'{name}: duplicate content types')
        missing = REQUIRED - set(types)
        if missing:
            raise ValueError(f'{name}: missing supported types: {sorted(missing)}')
        lists.append(set(types))
    if lists[0] != lists[1]:
        raise ValueError('Preview/Thumbnail content types differ')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    args = parser.parse_args()
    infos = []
    for target in ['QLExtension', 'ThumbnailExtension']:
        with (args.root / 'Sources' / target / 'Info.plist').open('rb') as stream:
            infos.append(plistlib.load(stream))
    validate(*infos)
    print('OK: Quick Look/Thumbnail supported content type contract')

if __name__ == '__main__':
    main()
