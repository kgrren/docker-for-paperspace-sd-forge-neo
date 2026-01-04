#!/usr/bin/env bash
set -euo pipefail

# This container provides the *environment* only.
# You will clone Forge Neo and create the venv from your own ipynb.
#
# Expected layout (matching the user's notebook workflow):
# - Repo: /notebooks/sd-webui-forge-neo
# - Venv: /tmp/sd-webui-forge-neo/venv
#
# This script is used by jupyter-server-proxy (Launcher entry).

REPO_DIR="${REPO_DIR:-/notebooks/sd-webui-forge-neo}"
VENV_DIR="${VENV_DIR:-/tmp/sd-webui-forge-neo/venv}"
PORT="${PORT:-7860}"
SUBPATH="${SUBPATH:-/proxy/${PORT}/}"

# Optional: central model folder (Neo supports --model-ref, but your ipynb may symlink models itself)
MODEL_REF="${MODEL_REF:-}"
OUTPUT_DIR="${OUTPUT_DIR:-}"

if [ ! -f "${REPO_DIR}/launch.py" ]; then
  echo "[start-forge] ERROR: ${REPO_DIR}/launch.py が見つかりません。" >&2
  echo "[start-forge] 先に ipynb で以下を実行してください:" >&2
  echo "  %cd /notebooks" >&2
  echo "  !rm -rf sd-webui-forge-neo" >&2
  echo "  !git clone https://github.com/Haoming02/sd-webui-forge-classic sd-webui-forge-neo --branch neo" >&2
  exit 1
fi

if [ ! -x "${VENV_DIR}/bin/python" ]; then
  echo "[start-forge] ERROR: venv が見つかりません: ${VENV_DIR}" >&2
  echo "[start-forge] 先に ipynb で以下を実行してください:" >&2
  echo "  !uv venv --seed --python 3.11 ${VENV_DIR}" >&2
  exit 1
fi

# Neo allows overriding the torch install command via TORCH_COMMAND.
# Keep your notebook's default, but allow env override.
export TORCH_COMMAND="${TORCH_COMMAND:-uv pip install torch==2.4.1+cu124 torchvision==0.19.1+cu124 --extra-index-url https://download.pytorch.org/whl/cu124}"

unset MPLBACKEND || true

ARGS=(
  --uv
  --pin-shared-memory
  --cuda-malloc
  --cuda-stream
  --enable-insecure-extension-access
  --port "${PORT}"
  --listen
  --subpath "${SUBPATH}"
)

# If you want to use Neo's central model folder feature, set MODEL_REF.
if [ -n "${MODEL_REF}" ]; then
  ARGS+=( --model-ref "${MODEL_REF}" )
fi

# Some users prefer to redirect outputs; keep opt-in.
if [ -n "${OUTPUT_DIR}" ]; then
  mkdir -p "${OUTPUT_DIR}" || true
  ARGS+=( --output-dir "${OUTPUT_DIR}" )
fi

exec "${VENV_DIR}/bin/python" -u "${REPO_DIR}/launch.py" "${ARGS[@]}"
