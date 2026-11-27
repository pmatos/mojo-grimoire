"""Tests for the explorer's servers, scripts/explorer.py and
scripts/explorer_specsite.py: the checks of a request, the paths they
serve, and runs and refusals over HTTP.
Run: python -m unittest discover -s scripts -p 'test_explorer*.py'"""

import http.client
import json
import os
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from argparse import Namespace
from pathlib import Path

import explorer
import explorer_proc
from explorer_specsite import SANDBOX, contained_file
from test_explorer import FAKE, script


class Security(unittest.TestCase):
    def setUp(self):
        self.ex = explorer.Explorer.__new__(explorer.Explorer)
        self.ex.token, self.ex.port = "s3cret", 8370
        self.good = {
            "Host": "127.0.0.1:8370",
            "Origin": "http://127.0.0.1:8370",
            "X-Explorer-Token": "s3cret",
        }

    def refused(self, headers, api=True, method="POST"):
        try:
            self.ex.check_request(headers, api, method)
        except explorer.Refused as e:
            return e.status
        return None

    def test_checks(self):
        self.assertIsNone(self.refused(self.good))
        local = {
            **self.good,
            "Host": "localhost:8370",
            "Origin": "http://localhost:8370",
        }
        self.assertIsNone(self.refused(local))
        self.assertEqual(self.refused({**self.good, "Host": "evil.test:8370"}), 421)
        self.assertEqual(self.refused({**self.good, "Origin": "http://evil.test"}), 403)
        self.assertEqual(self.refused({**self.good, "Origin": "null"}), 403)
        self.assertEqual(self.refused({**self.good, "X-Explorer-Token": "nope"}), 401)
        no_token = {k: v for k, v in self.good.items() if k != "X-Explorer-Token"}
        self.assertEqual(self.refused(no_token), 401)
        no_origin = {k: v for k, v in self.good.items() if k != "Origin"}
        self.assertEqual(self.refused(no_origin), 403)
        self.assertIsNone(self.refused(no_origin, method="GET"))
        cross = {**self.good, "Sec-Fetch-Site": "cross-site"}
        self.assertEqual(self.refused(cross), 403)
        page = {"Host": "127.0.0.1:8370"}
        self.assertIsNone(self.refused(page, api=False, method="GET"))

    def test_the_explorer_serves_only_its_page(self):
        self.assertEqual(self.ex.static_file("/"), explorer.UI / "index.html")
        self.assertEqual(self.ex.static_file("/ui/app.js"), explorer.UI / "app.js")
        for path in (
            "/ui/../explorer.py",
            "/ui/%2e%2e/explorer.py",
            "/ui/%2E%2E%2Fexplorer.py",
            "/spec/index.html",
            "/spec/The-static-checker/Errors/",
            "/ui/x%00",
            "/etc/passwd",
            "/ui//etc/passwd",
        ):
            with self.subTest(path=path), self.assertRaises(explorer.Refused):
                self.ex.static_file(path)

    def test_a_linked_index_cannot_escape(self):
        with tempfile.TemporaryDirectory() as name:
            root, outside = Path(name) / "root", Path(name) / "secret.html"
            (root / "dir").mkdir(parents=True)
            outside.write_text("secret")
            (root / "dir" / "index.html").symlink_to(outside)
            (root / "page.html").write_text("ok")
            self.assertIsNone(contained_file(root, "/dir/"))
            self.assertIsNone(contained_file(root, "/../secret.html"))
            self.assertEqual(
                contained_file(root, "/page.html"), (root / "page.html").resolve()
            )

    def test_bad_bodies(self):
        with self.assertRaises(explorer.Refused):
            self.ex.source_of({"source": 3})
        with self.assertRaises(explorer.Refused):
            self.ex.source_of({"source": "x" * (explorer.MAX_SOURCE + 1)})
        for fuel in (-1, True, "9", 10**12):
            with self.subTest(fuel=fuel), self.assertRaises(explorer.Refused):
                self.ex.fuel_of({"fuel": fuel})
        self.assertIsNone(self.ex.fuel_of({}))


class OverHttp(unittest.TestCase):
    """The two servers, with the stand-in compiler and model and a
    small rendered spec."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        base = Path(cls.tmp.name)
        model = script(base, "model", "#!/bin/sh\necho hi\n")
        (base / "spec" / "find").mkdir(parents=True)
        (base / "spec" / "index.html").write_text("<title>Spec</title>")
        (base / "spec" / "find" / "index.html").write_text("<script>x</script>")
        args = Namespace(
            mojo=FAKE,
            model=str(model),
            spec=str(base / "spec"),
            port=0,
            spec_port=0,
            jobs=2,
        )
        cls.server, cls.site, cls.ex = explorer.make_servers(args)
        cls.base = f"http://127.0.0.1:{cls.ex.port}"
        cls.spec = cls.ex.spec_base
        for s in (cls.server, cls.site):
            threading.Thread(target=s.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        for s in (cls.server, cls.site):
            s.shutdown()
            s.server_close()
        cls.tmp.cleanup()
        explorer_proc.configure(4, 8)

    def call(self, path, body=None, base=None, **headers):
        sent = {"X-Explorer-Token": self.ex.token, "Origin": self.base}
        sent.update(headers)
        data = json.dumps(body).encode() if body is not None else None
        if data is not None:
            sent["Content-Type"] = "application/json"
        request = urllib.request.Request((base or self.base) + path, data, sent)
        try:
            with urllib.request.urlopen(request, timeout=60) as res:
                return res.status, res.headers, res.read()
        except urllib.error.HTTPError as e:
            with e:
                return e.code, e.headers, e.read()

    def raw(self, method, path, headers, body=b""):
        conn = http.client.HTTPConnection("127.0.0.1", self.ex.port, timeout=30)
        try:
            conn.putrequest(method, path, skip_accept_encoding=True)
            for k, v in headers.items():
                conn.putheader(k, v)
            conn.endheaders(body)
            res = conn.getresponse()
            return res.status, res.read()
        finally:
            conn.close()

    def test_listens_on_loopback_only(self):
        self.assertEqual(self.server.server_address[0], "127.0.0.1")
        self.assertEqual(self.site.server_address[0], "127.0.0.1")
        self.assertNotEqual(self.server.server_address[1], self.site.server_address[1])

    def test_run(self):
        source = 'def main():\n    print("hi")\n'
        status, _, body = self.call("/api/run", {"source": source})
        answer = json.loads(body)
        self.assertEqual(status, 200)
        self.assertEqual(answer["compiler"]["result"]["stdout"], ["hi"])
        self.assertEqual(answer["verdict"]["state"], "agree")

    def test_refusals(self):
        self.assertEqual(self.call("/api/info", **{"X-Explorer-Token": "x"})[0], 401)
        self.assertEqual(self.call("/api/info", Origin="http://evil.test")[0], 403)
        self.assertEqual(self.call("/api/info", Host="evil.test")[0], 421)
        bad_level = {"source": "x", "level": "-O9"}
        self.assertEqual(self.call("/api/run", bad_level)[0], 400)

    def test_bad_content_lengths(self):
        head = {
            "Host": f"127.0.0.1:{self.ex.port}",
            "Origin": self.base,
            "X-Explorer-Token": self.ex.token,
            "Content-Type": "application/json",
        }
        for length in ("abc", "-5", "99999999999999999999", ""):
            with self.subTest(length=length):
                sent = {**head, "Content-Length": length} if length else head
                self.assertEqual(self.raw("POST", "/api/run", sent)[0], 400)
        sent = {**head, "Content-Length": str(explorer.MAX_BODY + 1)}
        self.assertEqual(self.raw("POST", "/api/run", sent)[0], 413)

    def test_slow_clients_time_out(self):
        self.assertEqual(self.server.RequestHandlerClass.timeout, 30)
        self.assertEqual(self.site.RequestHandlerClass.timeout, 30)

    def test_busy_beyond_the_queue(self):
        explorer_proc.configure(1, 0)
        try:
            with explorer_proc.GATE:
                status, _, body = self.call("/api/run", {"source": "x"})
            self.assertEqual(status, 503, body)
        finally:
            explorer_proc.configure(2, 4)

    def test_the_api_port_refuses_the_spec(self):
        for path in ("/spec/", "/spec/index.html", "/spec/find/?name=x", "/find/"):
            with self.subTest(path=path):
                self.assertEqual(self.call(path)[0], 404)

    def test_the_spec_is_sandboxed_on_its_own_origin(self):
        for path, status in (
            ("/", 200),
            ("/find/?name=%3Cimg%3E", 200),
            ("/nope", 404),
        ):
            with self.subTest(path=path):
                got, headers, _ = self.call(path, base=self.spec)
                self.assertEqual(got, status)
                self.assertEqual(headers["Content-Security-Policy"], SANDBOX)
                self.assertNotIn(
                    "allow-same-origin", headers["Content-Security-Policy"]
                )
        self.assertEqual(self.call("/api/info", base=self.spec)[0], 404)
        self.assertEqual(self.call("/", base=self.spec, Host="evil.test")[0], 421)

    def test_the_page_frames_only_the_spec(self):
        status, headers, _ = self.call("/")
        self.assertEqual(status, 200)
        policy = headers["Content-Security-Policy"]
        self.assertIn(f"frame-src {self.spec};", policy)
        self.assertIn("script-src 'self'", policy)

    def test_known_applies_to_the_default_build_and_explicit_o3(self):
        name = "arrays/or_unevaluated_literal_length"
        source = (explorer.ROOT / "tests" / "conformance" / f"{name}.mojo").read_text()
        for level, state in (
            ("default", "known"),
            ("-O3", "known"),
            ("-O0", "disagree"),
        ):
            with self.subTest(level=level):
                _, _, body = self.call("/api/run", {"source": source, "level": level})
                self.assertEqual(json.loads(body)["verdict"]["state"], state)

    def test_examples(self):
        status, _, body = self.call("/api/examples")
        self.assertEqual(status, 200)
        self.assertGreater(len(json.loads(body)), 100)
        status, _, body = self.call(
            "/api/example?name=arrays/or_unevaluated_literal_length"
        )
        self.assertEqual((status, json.loads(body)["entry"]), (200, "D-0014"))


if __name__ == "__main__":
    os.chdir(Path(__file__).resolve().parent)
    unittest.main()
