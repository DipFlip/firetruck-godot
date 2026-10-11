"""Publish a Godot web export under a content-specific URL, with a latest entry."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
from zipfile import ZipFile, ZIP_DEFLATED


def package(source: Path, destination: Path, archive: Path) -> dict:
    files = sorted(p for p in source.rglob('*') if p.is_file())
    digest = hashlib.sha256()
    for path in files:
        digest.update(path.relative_to(source).as_posix().encode() + b'\0')
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    build_id = digest.hexdigest()[:16]
    relative = Path('releases') / build_id
    release = destination / relative
    # Keep complete previous exports available to already-open tabs. Each new
    # export has new paths for its JS, PCK, WASM, worklets, fonts and textures.
    shutil.copytree(source, release, dirs_exist_ok=True)
    html = (release / 'index.html').read_text()
    html = html.replace('</head>', f'<meta name="firetruck-build" content="{build_id}">\n</head>')
    (release / 'index.html').write_text(html)
    manifest = {'id': build_id, 'entry': (relative / 'index.html').as_posix(),
                'pack_sha256': hashlib.sha256((source / 'index.pck').read_bytes()).hexdigest()}
    destination.mkdir(parents=True, exist_ok=True)
    manifest_temp = destination / 'build.json.tmp'
    manifest_temp.write_text(json.dumps(manifest, indent=2) + '\n')
    manifest_temp.replace(destination / 'build.json')
    entry = json.dumps('./' + manifest['entry'])
    # A relative redirect also works under GitHub Pages and itch.io subpaths.
    # Preserve QA/touch options when entering through the stable root URL.
    entry_temp = destination / 'index.html.tmp'
    entry_temp.write_text(
        '<!doctype html><html lang="en"><head><meta charset="utf-8">'
        '<title>Firetruck Frenzy</title></head><body>'
        f'<script>location.replace({entry}+location.search+location.hash);</script>'
        f'<a href="{manifest["entry"]}">Open Firetruck Frenzy</a></body></html>\n')
    entry_temp.replace(destination / 'index.html')
    (destination / '.nojekyll').touch()
    # Ship only this release, even when local preview retains earlier builds.
    with ZipFile(archive, 'w', ZIP_DEFLATED) as bundle:
        for name in ['index.html', 'build.json', '.nojekyll']:
            bundle.write(destination / name, name)
        for path in sorted(release.rglob('*')):
            if path.is_file(): bundle.write(path, path.relative_to(destination))
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('destination', type=Path)
    parser.add_argument('archive', type=Path)
    args = parser.parse_args()
    result = package(args.source, args.destination, args.archive)
    print(f'Web build: {args.destination / result["entry"]}')
    print(f'Local preview: http://localhost:8064/{result["entry"]}')
    print(f'Upload archive: {args.archive}')
