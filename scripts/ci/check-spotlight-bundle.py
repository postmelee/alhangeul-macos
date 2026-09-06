#!/usr/bin/env python3
"""Spotlight의 소스 및 앱 내부 bundle 계약 검사. 시스템 등록은 변경하지 않는다."""
import argparse
import os
from pathlib import Path
import plistlib
import sys
import uuid
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
IMPORTER_TYPE = "8B08C4BF-415B-11D8-B3F9-0003936726FC"
BUNDLE_PATH = Path("Contents/Library/Spotlight/Alhangeul.mdimporter")
IDENTIFIER = "com.postmelee.alhangeul.SpotlightImporter"
ATTRIBUTES = {"kMDItemTitle", "kMDItemKind", "kMDItemTextContent"}


def read_plist(path):
    with Path(path).open("rb") as stream:
        return plistlib.load(stream)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate(info, schema, host, executable=None):
    types = info["CFBundleDocumentTypes"]
    require(len(types) == 1 and types[0]["CFBundleTypeRole"] == "MDImporter", "MDImporter role mismatch")
    utis = types[0]["LSItemContentTypes"]
    expected = host["CFBundleDocumentTypes"][0]["LSItemContentTypes"]
    require(len(utis) == len(set(utis)) and set(utis) == set(expected), "HostApp UTI mismatch")
    require(info["CFPlugInDynamicRegistration"] == "NO", "dynamic registration is not supported")
    factories = info["CFPlugInFactories"]
    require(len(factories) == 1, "one factory is required")
    factory, function = next(iter(factories.items()))
    uuid.UUID(factory)
    require(function == "AlhangeulImporterFactory", "factory entrypoint mismatch")
    require(info["CFPlugInTypes"] == {IMPORTER_TYPE: [factory]}, "factory type mismatch")
    require(info["CFBundlePackageType"] == "BNDL", "package type mismatch")
    for key in ("CFBundleShortVersionString", "CFBundleVersion"):
        require(info[key] == host[key], f"HostApp {key} mismatch")
    tree = ET.parse(schema)
    ns = {"md": "http://www.apple.com/metadata"}
    declared = tree.findall("./md:types/md:type", ns)
    require(len(declared) == len(utis) and {node.attrib["name"] for node in declared} == set(utis), "schema UTI mismatch")
    for node in declared:
        require(set((node.findtext("md:allattrs", namespaces=ns) or "").split()) == ATTRIBUTES, "schema metadata mismatch")
    if executable is not None:
        require(info["CFBundleIdentifier"] == IDENTIFIER, "bundle identifier mismatch")
        require(info["CFBundleExecutable"] == "Alhangeul", "bundle executable mismatch")
        require(info["LSMinimumSystemVersion"] == "12.0", "minimum OS mismatch")
        require(executable.is_file() and os.access(executable, os.X_OK), "missing importer executable")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, help="실제 앱 bundle; 생략하면 source 계약만 검사")
    args = parser.parse_args()
    try:
        if args.app:
            bundle = args.app / BUNDLE_PATH
            validate(read_plist(bundle / "Contents/Info.plist"), bundle / "Contents/Resources/schema.xml",
                     read_plist(args.app / "Contents/Info.plist"), bundle / "Contents/MacOS/Alhangeul")
        else:
            validate(read_plist(ROOT / "Sources/SpotlightImporter/Info.plist"),
                     ROOT / "Sources/SpotlightImporter/schema.xml", read_plist(ROOT / "Sources/HostApp/Info.plist"))
    except (OSError, ValueError, KeyError, IndexError, ET.ParseError) as error:
        print(f"ERROR: Spotlight bundle contract: {error}", file=sys.stderr)
        return 1
    print("OK: Spotlight UTI, schema, factory, version and bundle contract")
    return 0


if __name__ == "__main__":
    sys.exit(main())
