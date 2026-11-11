#!/usr/bin/env python3
"""Local stand-in for a live radio station, used by the CI end-to-end jobs.

    python3 scripts/ci/loop_stream.py [--port 8099] [--host 0.0.0.0] [--log FILE] [--mp3 FILE]

Endpoints
  /stream  an endless MP3 stream: Content-Type audio/mpeg, no Content-Length, paced at
           the real bit rate like a live station (a short burst first so players fill
           their buffer). Without --mp3 the stream is made of silent MPEG-1 Layer III
           frames built in this file (128 kbps, 44.1 kHz), so nothing has to be
           installed; with --mp3 FILE that file's bytes are repeated forever.
  /dead    404, the negative control: a station that is gone.
  anything else: 404.

Each request is logged as one line ("GET /stream 127.0.0.1 ...") to stdout and, with
--log, to FILE, so a job can show that a client really connected. Standard library only.
"""
import argparse
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# MPEG-1 Layer III, 128 kbps, 44.1 kHz, stereo, no padding, no CRC. All-zero side info and
# main data decode as silence. 144 * 128000 / 44100 = 417.96 -> 417-byte frames.
FRAME = bytes([0xFF, 0xFB, 0x90, 0x00]) + bytes(417 - 4)
FRAME_SECONDS = 1152 / 44100
BURST_FRAMES = 150  # ~4 s sent at once, so a player can start without waiting

_log_lock = threading.Lock()
_log_file = None


def log(line):
    stamp = time.strftime("%H:%M:%S")
    with _log_lock:
        print(f"{stamp} {line}", flush=True)
        if _log_file is not None:
            _log_file.write(f"{stamp} {line}\n")
            _log_file.flush()


def chunks(mp3_path):
    """Yield (bytes, seconds_of_audio) forever."""
    if mp3_path is None:
        while True:
            yield FRAME, FRAME_SECONDS
    else:
        with open(mp3_path, "rb") as f:
            data = f.read()
        if not data:
            raise SystemExit(f"{mp3_path} is empty")
        # 128 kbps = 16000 bytes/s; a different bit rate only changes the pacing.
        step = 4096
        while True:
            for i in range(0, len(data), step):
                part = data[i : i + step]
                yield part, len(part) / 16000


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    mp3_path = None

    def log_message(self, fmt, *args):  # replaced by log() below
        pass

    def _cors(self):
        # The page's own metadata probe fetch()es the stream with an Icy-MetaData header.
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Expose-Headers", "*")

    def do_OPTIONS(self):
        log(f"OPTIONS {self.path} {self.client_address[0]}")
        self.send_response(204)
        self._cors()
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_HEAD(self):
        log(f"HEAD {self.path} {self.client_address[0]}")
        if self.path.split("?")[0] == "/stream":
            self.send_response(200)
            self.send_header("Content-Type", "audio/mpeg")
            self._cors()
            self.send_header("Connection", "close")
            self.end_headers()
        else:
            self._not_found()

    def _not_found(self):
        body = b"not found\n"
        self.send_response(404)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self._cors()
        self.send_header("Connection", "close")
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)
        self.close_connection = True

    def do_GET(self):
        path = self.path.split("?")[0]
        log(f"GET {self.path} {self.client_address[0]}")
        if path != "/stream":
            self._not_found()
            return
        self.send_response(200)
        self.send_header("Content-Type", "audio/mpeg")
        self.send_header("Cache-Control", "no-cache, no-store")
        self.send_header("icy-name", "CI loop stream")
        self._cors()
        self.send_header("Connection", "close")
        self.end_headers()
        self.close_connection = True
        start = time.monotonic()
        sent_seconds = 0.0
        try:
            for data, seconds in chunks(self.mp3_path):
                self.wfile.write(data)
                self.wfile.flush()
                sent_seconds += seconds
                # Stay about BURST_FRAMES ahead of real time, like a live feed.
                ahead = sent_seconds - (time.monotonic() - start) - BURST_FRAMES * FRAME_SECONDS
                if ahead > 0:
                    time.sleep(ahead)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            pass
        log(f"CLOSED {self.path} {self.client_address[0]} after {time.monotonic() - start:.1f}s")


def main():
    global _log_file
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--host", default="0.0.0.0")
    ap.add_argument("--port", type=int, default=8099)
    ap.add_argument("--log", help="also append the request log to this file")
    ap.add_argument("--mp3", help="repeat this MP3 file instead of the built-in silent frames")
    args = ap.parse_args()
    if args.log:
        _log_file = open(args.log, "a", encoding="utf-8")
    Handler.mp3_path = args.mp3
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    server.daemon_threads = True
    log(f"listening on {args.host}:{args.port} (/stream, /dead)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
