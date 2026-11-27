"""The explorer's second server, which serves only the rendered spec, on an
origin of its own (docs/decisions/conformance.md#the-explorer).

The spec's pages run Verso's scripts and scripts from a CDN, and Verso's
search page writes its query into the page as HTML. Served at the API's
origin, a link to that page could reach the API with the page's token. So
the spec has its own port, with no API and no token, and every response
carries a sandbox policy without `allow-same-origin`. A spec page then runs
in an opaque origin, which can read nothing of the explorer's.
"""

from __future__ import annotations

import mimetypes
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit

SANDBOX = "sandbox allow-scripts allow-popups"
REQUEST_TIMEOUT = 30


def contained_file(base: Path, rel: str) -> Path | None:
    """The file that the path `rel` names under `base`, a directory standing
    for its index.html; None when it is not there or lies outside `base`,
    through `..` or a link."""
    if "\0" in rel:
        return None
    root = base.resolve()
    target = (root / rel.lstrip("/")).resolve()
    if target.is_dir():
        target = (target / "index.html").resolve()
    if not target.is_relative_to(root) or not target.is_file():
        return None
    return target


def content_type(target: Path) -> str:
    kind = mimetypes.guess_type(target.name)[0] or "application/octet-stream"
    if kind.startswith("text/") or kind.endswith(("javascript", "json")):
        kind += "; charset=utf-8"
    return kind


def spec_handler(root: Path | None, port_of):
    """The handler of the spec's server; `port_of()` gives its port."""

    class SpecHandler(BaseHTTPRequestHandler):
        server_version = "mojo-explorer-spec"
        sys_version = ""
        timeout = REQUEST_TIMEOUT

        def log_message(self, format, *args):
            pass

        def send(self, status: int, body: bytes, kind: str) -> None:
            self.send_response(status)
            self.send_header("Content-Type", kind)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Content-Security-Policy", SANDBOX)
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Referrer-Policy", "no-referrer")
            # A sandboxed page has an opaque origin; this lets Verso's
            # scripts still fetch the spec's own public data files.
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(body)

        def do_GET(self):
            port = port_of()
            if self.headers.get("Host") not in {
                f"127.0.0.1:{port}",
                f"localhost:{port}",
            }:
                return self.send(421, b"wrong Host\n", "text/plain")
            path = unquote(urlsplit(self.path).path)
            target = contained_file(root, path) if root is not None else None
            if target is None:
                return self.send(404, b"not found\n", "text/plain")
            self.send(200, target.read_bytes(), content_type(target))

        do_HEAD = do_GET

    return SpecHandler


def make_spec_server(root: Path | None, port: int) -> ThreadingHTTPServer:
    """The spec's server, bound to 127.0.0.1 only."""
    server = ThreadingHTTPServer(("127.0.0.1", port), BaseHTTPRequestHandler)
    server.daemon_threads = True
    server.RequestHandlerClass = spec_handler(root, lambda: server.server_address[1])
    return server
