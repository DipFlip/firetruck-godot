"""Regression checks for consecutive exports and an already-cached preview."""
from functools import partial
from http.server import ThreadingHTTPServer
import json
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
from threading import Thread
from urllib.request import Request, urlopen
from zipfile import ZipFile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.package_web import package
from tools.serve_web import PreviewHandler


def run():
    with TemporaryDirectory() as temporary:
        folder = Path(temporary)
        source, destination = folder / 'export', folder / 'web'
        source.mkdir()
        (source / 'index.html').write_text('<html><head></head><body><script src="index.js"></script></body></html>')
        for name in ['index.js', 'index.wasm', 'index.audio.worklet.js', 'render_budget.js']:
            (source / name).write_bytes(b'unchanged engine bytes')
        (source / 'index.pck').write_bytes(b'old game')
        archive = folder / 'game.zip'
        first = package(source, destination, archive)
        (source / 'index.pck').write_bytes(b'new game')
        second = package(source, destination, archive)
        assert first['entry'] != second['entry'], 'A changed game pack must change the page and asset base URLs'
        assert package(source, destination, archive) == second, 'An identical export keeps its content ID'
        assert first['entry'] in [str(p.relative_to(destination)) for p in destination.rglob('index.html')], 'Existing tabs retain their complete old release'
        assert (destination / Path(first['entry']).parent / 'index.pck').read_bytes() == b'old game'
        assert json.loads((destination / 'build.json').read_text()) == second
        root = (destination / 'index.html').read_text()
        assert second['entry'] in root and 'location.search+location.hash' in root
        assert (destination / second['entry']).read_text().count('name="firetruck-build"') == 1
        with ZipFile(archive) as bundle:
            assert second['entry'] in bundle.namelist() and first['entry'] not in bundle.namelist(), 'Uploads contain only the latest release'
            assert bundle.read(str(Path(second['entry']).parent / 'index.pck')) == b'new game'
        class QuietHandler(PreviewHandler):
            def log_message(self, *args): pass
        server = ThreadingHTTPServer(('127.0.0.1', 0), partial(QuietHandler, directory=str(destination)))
        thread = Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            base = f'http://127.0.0.1:{server.server_port}/'
            for entry in ['', second['entry'], str(Path(second['entry']).parent / 'index.pck')]:
                request = Request(base + entry, headers={'If-Modified-Since': 'Wed, 01 Jan 2099 00:00:00 GMT', 'If-None-Match': 'old'})
                with urlopen(request) as response:
                    assert response.status == 200, 'An old cache validator must never cause a 304'
                    assert 'no-store' in response.headers['Cache-Control']
                    if entry.endswith('.pck'): assert response.read() == b'new game'
        finally:
            server.shutdown()
            server.server_close()
            thread.join()
    print('WEB CACHE: ALL PASS (changed pack, preserved tabs, latest archive, fresh conditional HTTP responses)')


if __name__ == '__main__': run()
