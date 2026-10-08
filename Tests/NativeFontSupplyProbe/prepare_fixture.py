"""승인된 합성 HWPX에서 nominal Regular 양성 대조군만 만든다. 원본을 수정하지 않는다."""
import pathlib
import re
import argparse
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument("source", type=pathlib.Path)
parser.add_argument("output", type=pathlib.Path)
parser.add_argument("--missing-glyph", action="store_true")
parser.add_argument("--installed-regular", action="store_true")
args = parser.parse_args()
source, output, missing = args.source, args.output, args.missing_glyph
if source.resolve() == output.resolve() or output.exists():
    raise SystemExit("새 출력 경로를 사용해야 합니다")
with zipfile.ZipFile(source) as original, zipfile.ZipFile(output, "w") as target:
    for entry in original.infolist():
        data = original.read(entry.filename)
        if entry.filename == "Contents/header.xml":
            data = re.sub(rb"<hh:bold\s*/>", b"", data)
            if args.installed_regular:
                before = b'face="Gowun Batang"'
                if before not in data: raise SystemExit("합성 입력의 글꼴 이름을 확인할 수 없습니다")
                data = data.replace(before, b'face="ArialUnicodeMS"')
        elif entry.filename == "Contents/section0.xml":
            text = data.decode("utf-8")
            retained = [False]
            def keep_one(match):
                content = ""
                if not retained[0] and match[2].strip():
                    retained[0] = True
                    content = "😀" if missing else "한글"
                return match[1] + content + match[3]
            text = re.sub(r"(<hp:t\b[^>]*>)(.*?)(</hp:t>)", keep_one, text, flags=re.S)
            data = text.encode("utf-8")
        target.writestr(entry, data)
