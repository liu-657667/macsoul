#!/usr/bin/env python3
"""Verify this visual-asset delivery snapshot (Python 3.9+, standard library only).

This does not execute Xcode or approve artwork. It does not rewrite the manifest.
Run at project root: python3 scripts/verify-visual-assets.py
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys
from typing import Any


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def safe_path(root: Path, relative: str) -> Path:
    p = (root / relative).resolve()
    if Path(relative).is_absolute() or not p.is_relative_to(root):
        raise ValueError(f'Path is outside project: {relative}')
    return p


def png_info(path: Path) -> dict[str, int]:
    with path.open('rb') as f:
        data = f.read(33)
    if len(data) != 33 or data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('Invalid PNG signature/header')
    if data[12:16] != b'IHDR' or struct.unpack('>I', data[8:12])[0] != 13:
        raise ValueError('Missing IHDR')
    w, h, bits, color = struct.unpack('>IIBB', data[16:26])
    if not w or not h:
        raise ValueError('Invalid PNG dimensions')
    return {'width': w, 'height': h, 'bit_depth': bits, 'color_type': color}


def verify(root: Path) -> dict[str, Any]:
    errors: list[str] = []
    warnings = [
        'MenuBar asset is a DRAFT, not approved for default production use.',
        'App icon preserves the opaque exterior dark matte; Dock review is pending.',
        'Static pass is not Xcode build, runtime UI, accessibility, or performance approval.',
    ]
    result: dict[str, Any] = {
        'kind': 'STATIC_ASSET_DELIVERY_CHECK',
        'status': 'FAIL',
        'files_checked': 0,
        'png_headers_checked': 0,
        'asset_sets_checked': 0,
        'errors': errors,
        'warnings': warnings,
        'not_run': ['actool', 'xcode_build', 'app_launch', 'dock_visual_check',
                    'menubar_light_dark_check', 'accessibility', 'performance'],
    }
    try:
        manifest = json.loads((root/'assets-source/asset-manifest.json').read_text(encoding='utf-8'))
        if manifest.get('version') != 1:
            raise ValueError('Unsupported manifest version')
    except (OSError, ValueError, json.JSONDecodeError) as e:
        errors.append(f'Manifest: {e}')
        return result

    seen: set[str] = set()
    for row in manifest.get('files', []):
        relative = row.get('path', '')
        try:
            if not relative or relative in seen:
                raise ValueError('Missing or duplicate path')
            seen.add(relative)
            p = safe_path(root, relative)
            if not p.is_file():
                raise ValueError('File missing')
            if p.stat().st_size != row['bytes']:
                errors.append(f'{relative}: size changed')
            if sha256(p) != row['sha256']:
                errors.append(f'{relative}: SHA-256 differs from delivery snapshot')
            result['files_checked'] += 1
            if 'png' in row:
                info = png_info(p)
                result['png_headers_checked'] += 1
                if info != row['png']:
                    errors.append(f'{relative}: PNG header mismatch: {info}')
        except (OSError, ValueError, KeyError, TypeError) as e:
            errors.append(f'{relative}: {e}')

    try:
        catalog = safe_path(root, manifest['catalog'])
        root_info = json.loads((catalog/'Contents.json').read_text(encoding='utf-8'))
        if root_info.get('info', {}).get('version') != 1:
            errors.append('Catalog Contents.json version must be 1')
        expected_names = set(manifest['asset_names'])
        actual = {p.stem for p in catalog.iterdir() if p.is_dir() and p.suffix in {'.imageset', '.appiconset'}}
        if actual != expected_names:
            errors.append(f'Asset names differ: expected={sorted(expected_names)}, actual={sorted(actual)}')
        for folder in sorted(catalog.iterdir()):
            if not folder.is_dir() or folder.suffix not in {'.imageset', '.appiconset'}:
                continue
            relative = str(folder.relative_to(root))
            try:
                content = json.loads((folder/'Contents.json').read_text(encoding='utf-8'))
                entries = content['images']
                slots: set[tuple[str, str]] = set()
                used_files: set[str] = set()
                for entry in entries:
                    if entry.get('idiom') != 'mac':
                        errors.append(f'{relative}: expected mac idiom')
                    filename = entry['filename']
                    if Path(filename).name != filename:
                        raise ValueError('Image filename must be local to its set')
                    used_files.add(filename)
                    info = png_info(folder/filename)
                    scale_str = entry['scale']
                    if scale_str not in {'1x', '2x'}:
                        raise ValueError(f'Unexpected scale {scale_str}')
                    scale = int(scale_str[:-1])
                    if folder.suffix == '.appiconset':
                        size = entry['size']
                        width, height = (int(x) for x in size.split('x'))
                        slot = (size, scale_str)
                        expected_pixels = (width*scale, height*scale)
                    else:
                        side = 18 if folder.stem == 'MacSoulMenuTemplateDraft' else 256
                        slot = ('image', scale_str)
                        expected_pixels = (side*scale, side*scale)
                        if info['color_type'] != 6:
                            errors.append(f'{relative}/{filename}: expected RGBA PNG')
                    if slot in slots:
                        errors.append(f'{relative}: duplicate slot {slot}')
                    slots.add(slot)
                    if (info['width'], info['height']) != expected_pixels:
                        errors.append(f'{relative}/{filename}: wrong scale/pixel dimensions')
                disk_files = {p.name for p in folder.glob('*.png')}
                if disk_files != used_files:
                    errors.append(f'{relative}: missing or unassigned PNG')
                if folder.suffix == '.appiconset':
                    expected_slots = {(f'{s}x{s}', scale) for s in (16,32,128,256,512) for scale in ('1x','2x')}
                    if slots != expected_slots:
                        errors.append(f'{relative}: must contain all 10 mac app-icon slots')
                else:
                    if slots != {('image','1x'), ('image','2x')}:
                        errors.append(f'{relative}: must contain 1x and 2x')
                    expected_render = 'template' if folder.stem == 'MacSoulMenuTemplateDraft' else 'original'
                    if content.get('properties', {}).get('template-rendering-intent') != expected_render:
                        errors.append(f'{relative}: wrong rendering intent')
                result['asset_sets_checked'] += 1
            except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as e:
                errors.append(f'{relative}: {e}')
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as e:
        errors.append(f'Catalog: {e}')
    result['status'] = 'PASS' if not errors else 'FAIL'
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--report', type=str, help='Optional new relative JSON report; never overwrite existing evidence')
    args = parser.parse_args()
    root = args.root.resolve()
    report = verify(root)
    payload = json.dumps(report, ensure_ascii=False, indent=2)+'\n'
    print(payload, end='')
    if args.report:
        try:
            p = safe_path(root, args.report)
            p.parent.mkdir(parents=True, exist_ok=True)
            with p.open('x', encoding='utf-8') as f:
                f.write(payload)
        except (OSError, ValueError) as e:
            print(f'Report not written: {e}', file=sys.stderr)
            return 2
    return 0 if report['status'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
