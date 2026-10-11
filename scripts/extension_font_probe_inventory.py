"""격리 후보·백업의 파일/링크/권한 대조. 읽기 전용이며 symlink를 따라가지 않는다."""
import hashlib
import json
import stat


def bundle_inventory(bundle):
    entries = {}
    for path in sorted(bundle.rglob('*')):
        key = path.relative_to(bundle).as_posix()
        mode = stat.S_IMODE(path.lstat().st_mode)
        if path.is_symlink():
            entries[key] = {'link': str(path.readlink()), 'mode': mode}
        elif path.is_file():
            entries[key] = {'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'mode': mode}
        elif path.is_dir():
            entries[key] = {'directory': True, 'mode': mode}
    return entries


def inventory_digest(entries):
    return hashlib.sha256(json.dumps(entries, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
