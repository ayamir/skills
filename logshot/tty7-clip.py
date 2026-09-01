#!/usr/bin/env python3
"""Send an image to tty7's local clipboard via the OSC 5522 streaming protocol.

tty7 (https://github.com/l0ng-ai/tty7) supports remote image clipboard writes
with a custom `OSC 5522` protocol (NOT standard OSC 52). This emits that protocol
on stdout so a terminal/agent can forward it to tty7 (over SSH or pty).

Usage:
    tty7-clip.py <image.png>              # print OSC 5522 frames to stdout
    tty7-clip.py <image.png> --probe      # also send the 'probe' capability check
"""
import base64
import os
import sys
import os
import select
import time

CHUNK = 4096   # tty7 MAX_CHUNK_BYTES
ST = b"\x1b\\"  # OSC terminator (tty7 uses ST, not BEL)

# tty7 supported_mime()
def mime_for(path):
    p = path.lower()
    if p.endswith(".png"):
        return "image/png"
    if p.endswith((".jpg", ".jpeg")):
        return "image/jpeg"
    if p.endswith(".gif"):
        return "image/gif"
    if p.endswith(".webp"):
        return "image/webp"
    return "image/png"

def frame(metadata: str, payload: bytes) -> bytes:
    # tty7's `osc(metadata, payload)`: separator only when payload is non-empty.
    sep = b";" if payload else b""
    return b"\x1b]5522;" + metadata.encode() + sep + payload + ST

def send(path: str, probe: bool = False):
    data = open(path, "rb").read()
    mime = mime_for(path)
    mid = base64.b64encode(mime.encode()).decode()  # mime is passed base64-encoded
    import uuid
    rid = uuid.uuid4().hex[:12]

    if probe:
        sys.stdout.buffer.write(b"\x1b]5522;probe" + b"" + ST)

    # 1) type=write opens the session; loc=clipboard required (not 'primary')
    sys.stdout.buffer.write(frame(f"type=write:id={rid}:loc=clipboard", b""))
    # 2) type=wdata chunks; EVERY chunk carries the base64-encoded mime (tty7
    #    rejects the second chunk if its mime differs from the first, and fails
    #    a non-empty chunk with no mime -> EINVAL).
    for i in range(0, len(data), CHUNK):
        chunk = data[i:i + CHUNK]
        mf = f"type=wdata:mime={mid}"
        payload = base64.b64encode(chunk)
        sys.stdout.buffer.write(frame(mf, payload))
    # 3) empty payload chunk terminates -> triggers Write
    sys.stdout.buffer.write(frame("type=wdata", b""))
    sys.stdout.buffer.flush()
    return rid

def listen_for_status(timeout: float = 2.0):
    """Read the terminal input stream briefly and report the OSC 5522 status reply
    from tty7 (DONE / EPERM / EINVAL / EBUSY). Reads from stdin, which in an
    interactive tty7 pane is the stream tty7 writes its reply into."""
    import re
    buf = b""
    deadline = time.time() + timeout
    while time.time() < deadline:
        r, _, _ = select.select([sys.stdin], [], [], 0.2)
        if r:
            try:
                ch = os.read(sys.stdin.fileno(), 4096)
            except Exception:
                break
            if not ch:
                break
            buf += ch
            m = re.search(rb"\x1b]5522;type=write:status=([A-Z]+)(?::id=([^\x1b]*))?\x1b\\", buf)
            if m:
                print(f"[tty7-clip] REPLY status={m.group(1).decode()} id={m.group(2).decode() if m.group(2) else '?'}", file=sys.stderr)
                return m.group(1).decode()
    return None

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    probe = "--probe" in sys.argv
    listen = "--listen" in sys.argv
    path = [a for a in sys.argv[1:] if a not in ("--probe", "--listen")][0]
    rid = send(path, probe)
    sys.stdout.flush()
    if listen:
        listen_for_status()
    # Normal exit so the stdout buffer is fully flushed to the pipe/terminal
    # before the process ends. A hard os._exit(0) can drop buffered frames
    # (logshot --clipboard showed ~350 vs the full 360 frames), which makes the
    # client reconstruct a truncated image. sys.exit runs the normal interpreter
    # teardown and flushes stdout.
    sys.exit(0)
