#!/usr/bin/env bash
set -euo pipefail

# Shared helpers for superopl-web scripts.

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing required command: $cmd" >&2
    return 1
  }
}

json_error() {
  local code="$1"
  local msg="$2"
  printf '{"status":"error","errors":[{"code":"%s","message":"%s"}]}' "$code" "$msg"
}
