#!/usr/bin/env python3
"""Content digest of source, project and verification inputs; excludes generated evidence."""
from pathlib import Path
import hashlib
root=Path(__file__).resolve().parent.parent
paths=[p for folder in ('MacSoul','MacSoulTests','MacSoul.xcodeproj','scripts') for p in (root/folder).rglob('*') if p.is_file() and 'xcuserdata' not in p.parts and '__pycache__' not in p.parts and p.suffix != '.pyc']
paths += [root/n for n in ('docs/DESIGN.md','docs/SCOPE.md') if (root/n).exists()]
h=hashlib.sha256()
for p in sorted(paths):
    h.update(str(p.relative_to(root)).encode()+b'\0'+p.read_bytes()+b'\0')
print(h.hexdigest())
