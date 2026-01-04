#!/usr/bin/env bash
set -euo pipefail

# JupyterLab must listen on 0.0.0.0:8888 for Paperspace
exec jupyter lab \
  --ServerApp.ip=0.0.0.0 \
  --ServerApp.port=8888 \
  --ServerApp.allow_origin=* \
  --ServerApp.open_browser=false \
  --ServerApp.allow_root=true \
  --ServerApp.root_dir=/notebooks \
  --ServerApp.token='' \
  --ServerApp.password=''
