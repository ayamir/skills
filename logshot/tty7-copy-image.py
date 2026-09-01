#!/usr/bin/env python3
import base64
import os
import pathlib
import re
import secrets
import select
import sys
import termios
import time
import tty

path = pathlib.Path(sys.argv[1])
mime = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".webp": "image/webp",
}.get(path.suffix.lower())
if mime is None:
    raise SystemExit("supported formats: png, jpg, jpeg, gif, webp")

data = path.read_bytes()
if len(data) > 16 * 1024 * 1024:
    raise SystemExit("image exceeds tty7's 16 MiB clipboard limit")

osc, st = b"\x1b]5522;", b"\x1b\\"
encoded_mime = base64.b64encode(mime.encode())
request_id = secrets.token_hex(8)
out = sys.stdout.buffer
fd = sys.stdin.fileno()
old = termios.tcgetattr(fd)
status = None
try:
    tty.setraw(fd)
    rid = request_id.encode()
    out.write(osc + b"type=write:id=" + rid + st)
    for offset in range(0, len(data), 4096):
        chunk = base64.b64encode(data[offset : offset + 4096])
        out.write(
            osc + b"type=wdata:id=" + rid + b":mime=" + encoded_mime + b";" + chunk + st
        )
    out.write(osc + b"type=wdata:id=" + rid + st)
    out.flush()

    reply = bytearray()
    pattern = re.compile(
        rb"\x1b\]5522;type=write:status=([A-Z]+):id=" + rid + rb"\x1b\\"
    )
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        ready, _, _ = select.select([fd], [], [], deadline - time.monotonic())
        if not ready:
            break
        reply.extend(os.read(fd, 4096))
        match = pattern.search(reply)
        if match:
            status = match.group(1).decode()
            break
finally:
    termios.tcsetattr(fd, termios.TCSADRAIN, old)

if status != "DONE":
    raise SystemExit(f"clipboard write failed: {status or 'timeout'}")
