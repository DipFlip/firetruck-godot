"""Serve the local game with caching disabled, including conditional requests."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class PreviewHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store, max-age=0')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

    def send_head(self):
        # A client may still have validators from the previous plain server.
        # Return fresh bytes instead of allowing a 304 to reuse that entry.
        for header in ['If-Modified-Since', 'If-None-Match']:
            if header in self.headers: del self.headers[header]
        return super().send_head()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8064)
    parser.add_argument('--bind', default='127.0.0.1')
    parser.add_argument('--directory', type=Path,
                        default=Path(__file__).resolve().parents[1] / 'builds/web')
    args = parser.parse_args()
    server = ThreadingHTTPServer((args.bind, args.port),
                                partial(PreviewHandler, directory=str(args.directory)))
    print(f'Preview: http://localhost:{args.port}/ (cache disabled)', flush=True)
    try: server.serve_forever()
    except KeyboardInterrupt: pass
    finally: server.server_close()
