#!/usr/bin/env python3
"""Expose only a synthetic fixture, assert email gate, and stop both processes.

This does not send email, access an inbox, or expose an existing local service.
"""
import http.server
import os
import queue
import re
import shutil
import subprocess
import tempfile
import threading
import time

MARKER = b"TUNNELBAR_SYNTHETIC_TEST_ONLY"


class Fixture(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(MARKER)

    def log_message(self, *_args):
        pass


def main():
    binary = shutil.which("cloudflared")
    if not binary:
        raise RuntimeError("cloudflared not installed")
    server = http.server.HTTPServer(("127.0.0.1", 0), Fixture)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        with tempfile.TemporaryDirectory(prefix="tunnelbar-smoke-") as folder:
            config = os.path.join(folder, "config.yml")
            with open(config, "w") as handle:
                handle.write("{}\n")
            env = {k: v for k, v in os.environ.items()
                   if not k.startswith(("TUNNEL_", "CLOUDFLARED_"))}
            child = subprocess.Popen([
                binary, "tunnel", "--config", config, "--no-autoupdate",
                "--metrics", "127.0.0.1:0", "--grace-period", "2s",
                "--url", f"http://localhost:{server.server_port}",
                "--allowed-mail", "tunnelbar-test@example.com",
            ], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env)
            lines = queue.Queue()
            threading.Thread(target=lambda: [lines.put(line) for line in child.stdout], daemon=True).start()
            try:
                url = None
                connected = False
                deadline = time.monotonic() + 45
                recent = []
                while time.monotonic() < deadline and not (url and connected):
                    if child.poll() is not None and lines.empty():
                        break
                    try:
                        line = lines.get(timeout=0.5)
                    except queue.Empty:
                        continue
                    recent = (recent + [line.rstrip()])[-12:]
                    match = re.search(r"https://[a-z0-9-]+\.trycloudflare\.com", line)
                    if match:
                        url = match.group(0)
                    connected |= "Registered tunnel connection" in line
                if not (url and connected):
                    raise RuntimeError("Protected connector did not become ready:\n" + "\n".join(recent))
                # Allow a short interval for hostname propagation; never accept the fixture anonymously.
                for attempt in range(5):
                    response_path = os.path.join(folder, "response.html")
                    # macOS curl uses the system trust store, including installed local CAs.
                    response = subprocess.run([
                        "/usr/bin/curl", "--location", "--silent", "--show-error", "--fail",
                        "--max-time", "12", "--output", response_path,
                        "--write-out", "%{url_effective}", url,
                    ], capture_output=True, text=True)
                    if response.returncode == 0:
                        with open(response_path, "rb") as handle:
                            body = handle.read(1_000_000)
                        final_url = response.stdout
                        assert MARKER not in body, "Origin was reachable without email authentication"
                        assert b"email" in body.lower(), "Expected an email sign-in form"
                        assert "access" in final_url.lower() or b"one-time" in body.lower() or b"cloudflare access" in body.lower(), "Expected Cloudflare email gate"
                        print("PASS: protected Quick Tunnel connected; anonymous visitor received the email gate, not the fixture.")
                        break
                    else:
                        if attempt == 4:
                            raise RuntimeError(response.stderr)
                        time.sleep(1)
            finally:
                child.terminate()
                try:
                    child.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait()
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
