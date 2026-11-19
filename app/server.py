from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import os
import socket


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/healthz", "/readyz"):
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"ok\n")
            return

        body = (
            f"Hello from Kubernetes!\n"
            f"Host: {socket.gethostname()}\n"
            f"Version: {os.getenv('APP_VERSION', 'local')}\n"
        ).encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        print(f"{self.address_string()} - {format % args}")


ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
