#!/usr/bin/env bash
set -euo pipefail

: "${CADDY_FILE_PREVIEW_ROOT:?must point to the same directory used at start time}"

STATE_DIR="${CADDY_FILE_PREVIEW_STATE_DIR:-${CADDY_FILE_PREVIEW_ROOT}/.caddy-state}"
PID_FILE="$STATE_DIR/caddy.pid"

if [[ ! -f "$PID_FILE" ]]; then
  echo "No pid file found at $PID_FILE"
  exit 0
fi

PID="$(cat "$PID_FILE")"
if kill -0 "$PID" 2>/dev/null; then
  kill "$PID"
  for _ in $(seq 1 20); do
    if ! kill -0 "$PID" 2>/dev/null; then
      rm -f "$PID_FILE"
      echo "Stopped Caddy file server pid $PID"
      exit 0
    fi
    sleep 0.25
  done
  kill -9 "$PID" 2>/dev/null || true
fi

rm -f "$PID_FILE"
echo "Stopped Caddy file server pid $PID"
