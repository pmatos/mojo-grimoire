#!/usr/bin/env python3
"""A local explorer, in the style of Compiler Explorer, that runs one Mojo
program on the pinned compiler and on the Lean model side by side
(docs/decisions/conformance.md#the-explorer).

Usage:
  scripts/explorer.py [--mojo WRAPPER] [--model EXE] [--spec DIR]
                      [--port N] [--spec-port N] [--jobs N]
      Serves the explorer on http://127.0.0.1:N/, 8370 unless --port says,
      and the rendered spec on a port of its own, the next one unless
      --spec-port says, and prints the explorer's URL with this session's
      token. The compiler is the wrapper that scripts/install-mojo.sh
      prints, from --mojo or $MOJO; the model is
      lean/.lake/build/bin/mojo-grimoire, built with scripts/build-lean.sh;
      the spec is docs/spec/_out/html-multi, rendered with
      scripts/build-spec.sh. --jobs N runs at most N processes at once (4),
      and queues at most twice as many more.

It runs arbitrary code. It listens on 127.0.0.1 only. Every API call needs
the session's token and the explorer's own Host, and the explorer's Origin
when one is sent, as a POST always sends one; the spec is served on another
origin, sandboxed (explorer_specsite.py). Each run has a fresh temporary
directory, a timeout, a cap on its output and resource limits
(explorer_proc.py), and none of its processes outlives it (explorer_reap.py).
"""

from __future__ import annotations

import argparse
import hmac
import json
import os
import secrets
import subprocess
import sys
import threading
from concurrent.futures import ThreadPoolExecutor
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlsplit

import explorer_proc
import explorer_reap
import explorer_run as run
import explorer_spec as spec
from conformance import MODEL, ROOT, load_patterns
from explorer_specsite import (
    REQUEST_TIMEOUT,
    contained_file,
    content_type,
    make_spec_server,
)
from explorer_suite import Suite

UI = Path(__file__).resolve().parent / "explorer-ui"
SPEC = ROOT / "docs" / "spec" / "_out" / "html-multi"
MAX_BODY = 256 * 1024
MAX_SOURCE = 100 * 1024
TOKEN_HEADER = "X-Explorer-Token"
PAGE_POLICY = (
    "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; "
    "connect-src 'self'; frame-src {spec}; base-uri 'none'; form-action 'none'; "
    "frame-ancestors 'self'"
)


class Refused(Exception):
    def __init__(self, status: int, why: str) -> None:
        super().__init__(why)
        self.status = status


class Explorer:
    """What the server knows for a session: its token, the compiler, the
    model, the spec's index and the suite."""

    def __init__(self, args, port: int, spec_port: int) -> None:
        self.token = secrets.token_urlsafe(32)
        self.port = port
        self.spec_base = f"http://127.0.0.1:{spec_port}"
        self.policy = PAGE_POLICY.format(spec=self.spec_base)
        self.mojo = args.mojo
        self.model = Path(args.model)
        self.jobs = max(1, args.jobs)
        self.limits = run.Limits()
        explorer_proc.configure(self.jobs, 2 * self.jobs)
        self.patterns = load_patterns()
        self.suite = Suite()
        self.index = spec.build_index(Path(args.spec) if args.spec else None)
        self.tokens = spec.load_tokens(UI / "tokens.json")
        self.warnings = self.index.warnings + spec.check_tokens(self.tokens, self.index)
        self.warnings += stale_model(self.model)
        self.info = {
            "model": model_info(self.model),
            "compiler": compiler_version(self.mojo),
            "spec": {
                "available": self.index.root is not None,
                "commit": self.index.commit,
            },
            "levels": ["default", *run.SWEEP_LEVELS],
            "warnings": self.warnings,
        }
        self.spec_payload = spec.spec_payload(self.tokens, self.index, self.spec_base)

    # --- the checks of a request -----------------------------------------

    def hosts(self) -> set[str]:
        return {f"127.0.0.1:{self.port}", f"localhost:{self.port}"}

    def check_request(self, headers, api: bool, method: str) -> None:
        """Refuses a request from anywhere but the explorer's own page:
        another Host (DNS rebinding), another Origin, a cross-site fetch,
        and, for the API, a missing or wrong token."""
        if headers.get("Host") not in self.hosts():
            raise Refused(421, "wrong Host")
        origin = headers.get("Origin")
        if origin is not None and origin not in {f"http://{h}" for h in self.hosts()}:
            raise Refused(403, "wrong Origin")
        if not api:
            return
        if method == "POST" and origin is None:
            raise Refused(403, "no Origin")
        if headers.get("Sec-Fetch-Site") not in (None, "same-origin", "none"):
            raise Refused(403, "cross-site request")
        given = headers.get(TOKEN_HEADER) or ""
        if not hmac.compare_digest(given.encode(), self.token.encode()):
            raise Refused(401, "missing or wrong token")

    # --- the API ------------------------------------------------------------

    def source_of(self, body: dict) -> str:
        source = body.get("source")
        if not isinstance(source, str) or len(source.encode()) > MAX_SOURCE:
            raise Refused(400, f"source must be text of at most {MAX_SOURCE} bytes")
        return source

    def fuel_of(self, body: dict) -> int | None:
        fuel = body.get("fuel")
        if fuel in (None, ""):
            return None
        if not isinstance(fuel, int) or isinstance(fuel, bool) or not 0 < fuel < 10**9:
            raise Refused(400, "fuel must be a positive integer")
        return fuel

    def compile(self, source: str, flags: tuple[str, ...]) -> dict:
        return run.run_on_compiler(source, self.mojo, self.patterns, flags, self.limits)

    def on_model(self, source: str, fuel: int | None) -> dict:
        return run.run_on_model(source, self.model, fuel, self.limits)

    def suite_of(self, source: str):
        example = self.suite.match(source)
        return example, (self.suite.describe(example) if example else None)

    def run(self, body: dict) -> dict:
        source, fuel = self.source_of(body), self.fuel_of(body)
        level = body.get("level", "default")
        try:
            flags = run.level_flags(level)
        except ValueError as e:
            raise Refused(400, str(e)) from e
        with ThreadPoolExecutor(2) as pool:
            compiled = pool.submit(self.compile, source, flags)
            modelled = pool.submit(self.on_model, source, fuel)
            compiler, model = compiled.result(), modelled.result()
        example, suite = self.suite_of(source)
        # known.json and the record are of the default build, which is -O3.
        recorded_level = level in ("default", "-O3")
        known = example.known if example and recorded_level else None
        expected, actual = compiler["_result"], model["_result"]
        answer = {
            "level": level,
            "compiler": run._public(compiler),
            "model": run._public(model),
            "verdict": run.verdict(expected, actual, known),
            "suite": suite,
        }
        if example and example.expected and recorded_level:
            answer["checkVerdict"] = run.verdict(example.expected, actual, known)
        return answer

    def sweep(self, body: dict) -> dict:
        source, fuel = self.source_of(body), self.fuel_of(body)
        model = self.on_model(source, fuel)
        rows = run.sweep_levels(
            lambda flags: self.compile(source, flags), self.jobs, model["_result"]
        )
        _, suite = self.suite_of(source)
        return {"model": run._public(model), "levels": rows, "suite": suite}

    def get_api(self, path: str, query: dict) -> dict | list:
        if path == "/api/info":
            return self.info
        if path == "/api/spec":
            return self.spec_payload
        if path == "/api/examples":
            return self.suite.listing()
        if path == "/api/example":
            example = self.suite.examples.get(query.get("name", [""])[0])
            if example is None:
                raise Refused(404, "no such suite program")
            return {**self.suite.describe(example), "source": example.path.read_text()}
        if path == "/api/entry":
            entry = self.suite.entry(query.get("id", [""])[0])
            if entry is None:
                raise Refused(404, "no such decision-log entry")
            return entry
        raise Refused(404, "no such API")

    def post_api(self, path: str, body: dict) -> dict:
        if path == "/api/run":
            return self.run(body)
        if path == "/api/sweep":
            return self.sweep(body)
        raise Refused(404, "no such API")

    def static_file(self, path: str) -> Path:
        """The page's file that a path names, under the UI only; the spec
        has its own server."""
        rel = unquote(path)
        if rel in ("/", "/index.html"):
            return UI / "index.html"
        if rel.startswith("/ui/") and (target := contained_file(UI, rel[4:])):
            return target
        raise Refused(404, "not found")


def model_info(model: Path) -> dict:
    """The commit of the checkout that the model was built in."""

    def git(*args: str) -> str:
        proc = subprocess.run(
            ["git", "-C", str(ROOT), *args],
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        return proc.stdout.strip()

    dirty = bool(git("status", "--porcelain", "--", "lean"))
    return {
        "commit": git("rev-parse", "--short=12", "HEAD"),
        "dirty": dirty,
        "built": model.is_file(),
    }


def stale_model(model: Path) -> list[str]:
    if not model.is_file():
        return [f"no model at {model}; run scripts/build-lean.sh"]
    built = model.stat().st_mtime
    sources = (ROOT / "lean").glob("MojoGrimoire/**/*.lean")
    if any(p.stat().st_mtime > built for p in sources):
        return [
            "lean/ has changed since the model was built; run scripts/build-lean.sh"
        ]
    return []


def compiler_version(mojo: str) -> str:
    try:
        proc = subprocess.run(
            [mojo, "--version"], capture_output=True, text=True, timeout=60, check=False
        )
    except (OSError, subprocess.TimeoutExpired) as e:
        return f"unavailable: {e}"
    return proc.stdout.strip() or proc.stderr.strip()


def handler_for(explorer: Explorer):
    class Handler(BaseHTTPRequestHandler):
        server_version = "mojo-explorer"
        sys_version = ""
        timeout = REQUEST_TIMEOUT

        def log_message(self, format, *args):
            sys.stderr.write(
                f"{self.command} {urlsplit(self.path).path}: "
                f"{args[1] if len(args) > 1 else ''}\n"
            )

        def send(self, status: int, body: bytes, kind: str, page: bool = False):
            self.send_response(status)
            self.send_header("Content-Type", kind)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Referrer-Policy", "no-referrer")
            self.send_header("X-Frame-Options", "SAMEORIGIN")
            self.send_header("Cache-Control", "no-store")
            if page:
                self.send_header("Content-Security-Policy", explorer.policy)
            self.end_headers()
            self.wfile.write(body)

        def send_json(self, status: int, data) -> None:
            self.send(status, json.dumps(data).encode(), "application/json")

        def handle_any(self, method: str) -> None:
            url = urlsplit(self.path)
            api = url.path.startswith("/api/")
            try:
                explorer.check_request(self.headers, api, method)
                if api and method == "GET":
                    return self.send_json(
                        200, explorer.get_api(url.path, parse_qs(url.query))
                    )
                if api:
                    return self.send_json(
                        200, explorer.post_api(url.path, self.read_body())
                    )
                if method != "GET":
                    raise Refused(405, "method not allowed")
                target = explorer.static_file(url.path)
                self.send(200, target.read_bytes(), content_type(target), page=True)
            except explorer_proc.Busy as e:
                self.send_json(503, {"error": str(e)})
            except Refused as e:
                self.send_json(e.status, {"error": str(e)})
            except Exception as e:
                # The page shows why, rather than a dropped connection.
                self.send_json(500, {"error": f"{type(e).__name__}: {e}"})
                raise

        def read_body(self) -> dict:
            kind = (self.headers.get("Content-Type") or "").split(";")[0].strip()
            if kind != "application/json":
                raise Refused(415, "the body must be application/json")
            given = (self.headers.get("Content-Length") or "").strip()
            if not given.isdigit() or len(given) > 9:
                raise Refused(400, "the body needs a valid Content-Length")
            length = int(given)
            if not 0 < length <= MAX_BODY:
                raise Refused(413, f"the body must be at most {MAX_BODY} bytes")
            try:
                body = json.loads(self.rfile.read(length))
            except ValueError as e:
                raise Refused(400, "the body is not JSON") from e
            if not isinstance(body, dict):
                raise Refused(400, "the body must be an object")
            return body

        def do_GET(self):
            self.handle_any("GET")

        def do_POST(self):
            self.handle_any("POST")

    return Handler


def parse_args(argv: list[str]):
    p = argparse.ArgumentParser(
        description="Run a Mojo program on the compiler and the model side by side."
    )
    p.add_argument(
        "--mojo",
        default=os.environ.get("MOJO"),
        help="the compiler wrapper (default: $MOJO)",
    )
    p.add_argument("--model", default=str(MODEL), help="the model's executable")
    p.add_argument("--spec", default=str(SPEC), help="the rendered spec")
    p.add_argument("--port", type=int, default=8370)
    p.add_argument(
        "--spec-port", type=int, help="the spec's port (default: --port + 1)"
    )
    p.add_argument("--jobs", type=int, default=4)
    args = p.parse_args(argv)
    if not args.mojo:
        p.error("give the compiler wrapper with --mojo WRAPPER or $MOJO")
    return args


def make_servers(args):
    """The explorer's server and the spec's, both bound to 127.0.0.1 only,
    and the session."""
    server = ThreadingHTTPServer(("127.0.0.1", args.port), BaseHTTPRequestHandler)
    server.daemon_threads = True
    port = server.server_address[1]
    spec_port = (
        args.spec_port if args.spec_port is not None else (port + 1 if port else 0)
    )
    root = Path(args.spec) if args.spec else None
    site = make_spec_server(root if root and root.is_dir() else None, spec_port)
    explorer = Explorer(args, port, site.server_address[1])
    server.RequestHandlerClass = handler_for(explorer)
    return server, site, explorer


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    server, site, explorer = make_servers(args)
    port = explorer.port
    threading.Thread(target=site.serve_forever, daemon=True).start()
    if not explorer_reap.become_subreaper():
        explorer.warnings.append(
            "cannot become a subreaper; a run's process that leaves its tree "
            "and its environment marker may outlive it"
        )
    explorer_reap.start_reaper()
    for w in explorer.warnings:
        print(f"warning: {w}", file=sys.stderr)
    print(f"compiler: {explorer.info['compiler']}")
    print(f"Open http://127.0.0.1:{port}/?token={explorer.token}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        site.shutdown()
        site.server_close()
        explorer_reap.reap_orphans()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
