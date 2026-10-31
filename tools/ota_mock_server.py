#!/usr/bin/env python3
"""Nep-GitHub voor tests/ota_test.gd: dient een release "updates" met manifest.json en een patchbestand.
Gedrag zoals de echte API voor een privé-repo: de assets zijn alleen met een token op te halen, geven een doorverwijzing (302)
naar een opslag-URL, en die opslag-URL weigert een Authorization-header (zoals echte blobopslag).
Gebruik: ota_mock_server.py <poort> <manifest.json> <patchbestand> [token]"""
import http.server, json, sys, os

port = int(sys.argv[1])
manifest_pad, patch_pad = sys.argv[2], sys.argv[3]
TOKEN = sys.argv[4] if len(sys.argv) > 4 else "testtoken"
manifest = open(manifest_pad, "rb").read()
patch = open(patch_pad, "rb").read()
naam = json.loads(manifest)["pck"]["naam"]
BASE = f"http://127.0.0.1:{port}"


class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _auth(self):
        return self.headers.get("Authorization") == "Bearer " + TOKEN

    def _send(self, code, body=b"", ctype="application/octet-stream", extra=None):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        p = self.path
        if p == "/repos/boodschappenmaatje/Bloedjungle-godot/releases/tags/updates":
            if not self._auth():
                return self._send(401, b'{"message":"Bad credentials"}', "application/json")
            body = json.dumps({"assets": [{"name": "manifest.json", "id": 1, "url": BASE + "/api-asset/1"},
                                          {"name": naam, "id": 2, "url": BASE + "/api-asset/2"}]}).encode()
            return self._send(200, body, "application/json")
        if p.startswith("/api-asset/"):
            if not self._auth():
                return self._send(404, b'{"message":"Not Found"}', "application/json")
            return self._send(302, b"", extra={"Location": BASE + "/blob/" + p.rsplit("/", 1)[1]})
        if p.startswith("/api-direct/"):
            if not self._auth():
                return self._send(404, b'{"message":"Not Found"}', "application/json")
            return self._send(200, patch)
        if p.startswith("/blob/"):
            if self.headers.get("Authorization"):
                return self._send(400, b"blobopslag weigert een Authorization-header")
            return self._send(200, manifest if p.endswith("/1") else patch)
        self._send(404, b"?")


http.server.ThreadingHTTPServer(("127.0.0.1", port), H).serve_forever()
