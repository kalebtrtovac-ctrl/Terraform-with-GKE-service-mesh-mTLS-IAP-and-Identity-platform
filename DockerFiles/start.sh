#!/bin/bash
# Simple start script to run a basic HTTP server for the Tetris app

set -euo pipefail

PORT="${PORT:-8080}"
exec python3 -m http.server "$PORT" --bind 0.0.0.0