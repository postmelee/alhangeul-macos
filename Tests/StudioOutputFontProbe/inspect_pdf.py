#!/usr/bin/env python3
"""자체 합성 PDF의 font program/ToUnicode만 검사한다. pypdf가 있는 Python 필요."""
import argparse
import hashlib
import json
from pathlib import Path
import pypdf

def inspect(pdf):
    reader = pypdf.PdfReader(pdf)
    result, seen = [], set()

    def visit(resources, depth=0):
        if not resources or depth > 16:
            return
        resources = resources.get_object()
        for reference in resources.get("/Font", {}).get_object().values() if resources.get("/Font") else []:
            font = reference.get_object()
            key = (getattr(reference, "idnum", None), str(font.get("/BaseFont", "")))
            if key in seen:
                continue
            seen.add(key)
            descendants = font.get("/DescendantFonts")
            embedded_font = descendants[0].get_object() if descendants else font
            descriptor = embedded_font.get("/FontDescriptor")
            programs = {}
            if descriptor:
                descriptor = descriptor.get_object()
                for field in ["/FontFile", "/FontFile2", "/FontFile3"]:
                    if field in descriptor:
                        data = descriptor[field].get_object().get_data()
                        programs[field] = {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
            cmap = font.get("/ToUnicode")
            cmap = cmap.get_object().get_data() if cmap else None
            result.append({"baseFont": str(font.get("/BaseFont", "")), "subtype": str(font.get("/Subtype", "")),
                           "descendantSubtype": str(embedded_font.get("/Subtype", "")),
                           "encoding": str(font.get("/Encoding", "")), "programs": programs,
                           "toUnicodeBytes": len(cmap) if cmap else 0,
                           "toUnicodeSHA256": hashlib.sha256(cmap).hexdigest() if cmap else None})
        objects = resources.get("/XObject")
        if objects:
            for value in objects.get_object().values():
                value = value.get_object()
                if value.get("/Subtype") == "/Form":
                    visit(value.get("/Resources"), depth + 1)
    for page in reader.pages:
        visit(page.get("/Resources"))
    return {"pypdf": pypdf.__version__, "pages": len(reader.pages), "fonts": result}

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pdf", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    value = inspect(args.pdf)
    for ps in ["GowunBatang-Regular", "GowunBatang-Bold"]:
        rows = [font for font in value["fonts"] if font["baseFont"].endswith("+" + ps)]
        assert rows and all(font["programs"] for font in rows), ps
        assert any(font["toUnicodeBytes"] for font in rows), ps
    args.output.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
    print("고운바탕 두 face의 font program과 한글 ToUnicode 확인")
