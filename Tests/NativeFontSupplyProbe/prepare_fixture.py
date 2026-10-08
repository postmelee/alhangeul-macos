"""승인된 합성 HWPX에서 nominal Regular 양성 대조군만 만든다. 원본을 수정하지 않는다."""
import pathlib
import re
import sys
import zipfile

source, output = map(pathlib.Path, sys.argv[1:3])
missing = sys.argv[3:] == ["--missing-glyph"]
if sys.argv[3:] and not missing:
    raise SystemExit("알 수 없는 옵션")
if source.resolve() == output.resolve() or output.exists():
    raise SystemExit("새 출력 경로를 사용해야 합니다")
with zipfile.ZipFile(source) as original, zipfile.ZipFile(output, "w") as target:
    for entry in original.infolist():
        data = original.read(entry.filename)
        if entry.filename == "Contents/header.xml":
            data = re.sub(rb"<hh:bold\s*/>", b"", data)
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
