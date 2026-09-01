#!/usr/bin/env python3
"""herdr-live-handoff - hand a running herdr server off to a NEW herdr binary.

herdr is a background server + reattachable client. `server.live_handoff` API
tells the running server to transfer all live panes / terminal FDs to a new
binary (`import_exe`), then the old server exits. Agents/processes keep running.

Usage:
    herdr-live-handoff.py <new-herdr-binary> [socket_path] [--dry-run]
        <new-herdr-binary>   path to the patched herdr binary to take over
        socket_path          default ~/.config/herdr/herdr.sock
        --dry-run            only ping + confirm, do NOT hand off

Safety: only the owner should run this; it detaches live panes to the new server.
"""
import json
import os
import socket
import sys

def send(sock_path: str, method: str, params: dict, request_id: str) -> dict:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(sock_path)
    req = {"id": request_id, "method": method, "params": params}
    s.sendall(json.dumps(req).encode())
    s.shutdown(socket.SHUT_WR)
    # read one line (JSON) of response
    buf = b""
    while True:
        chunk = s.recv(65536)
        if not chunk:
            break
        buf += chunk
        if b"\n" in buf:
            break
    s.close()
    return json.loads(buf.decode())

def main():
    args = [a for a in sys.argv[1:] if a != "--dry-run"]
    dry = "--dry-run" in sys.argv
    if len(args) < 1:
        print(__doc__)
        sys.exit(1)
    new_exe = os.path.abspath(args[0])
    sock_path = args[1] if len(args) > 1 else os.path.expanduser("~/.config/herdr/herdr.sock")

    print(f"* new binary : {new_exe}")
    print(f"* api socket : {sock_path}")
    if not os.path.exists(sock_path):
        print("! socket not found; is the herdr server running?", file=sys.stderr)
        sys.exit(1)
    if not os.path.exists(new_exe):
        print("! new binary not found:", new_exe, file=sys.stderr)
        sys.exit(1)

    # connectivity check
    try:
        pong = send(sock_path, "ping", {}, "handoff-ping")
        print("* ping ok:", pong)
    except Exception as e:
        print("! ping failed:", e, file=sys.stderr)
        sys.exit(1)

    if dry:
        print("* --dry-run: skipping handoff. Remove --dry-run to execute.")
        sys.exit(0)

    # The handoff commits the live panes to the new server; this is not reversible.
    print("! Executing live handoff: transferring live panes to:", new_exe)
    try:
        resp = send(sock_path, "server.live_handoff", {"import_exe": new_exe}, "handoff-exec")
        print("* response:", resp)
    except Exception as e:
        print("! handoff request error:", e, file=sys.stderr)

if __name__ == "__main__":
    main()
