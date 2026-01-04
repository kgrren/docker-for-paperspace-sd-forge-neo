#!/usr/bin/env bash
set -euo pipefail

# Paperspace Notebook front-proxy can rewrite headers/hosts.
# These flags prevent "works in terminal but not in UI" style issues.
JUPYTER_PORT="${JUPYTER_PORT:-8888}"
ROOT_DIR="${JUPYTER_ROOT_DIR:-/notebooks}"

exec python3.11 -m jupyter lab \
  --ip=0.0.0.0 \
  --port="${JUPYTER_PORT}" \
  --no-browser \
  --ServerApp.root_dir="${ROOT_DIR}" \
  --ServerApp.allow_remote_access=True \
  --ServerApp.trust_xheaders=True \
  --ServerApp.disable_check_xsrf=True \
  --ServerApp.token='' \
  --ServerApp.password=''
