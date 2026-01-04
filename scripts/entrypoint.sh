#!/usr/bin/env bash
set -euo pipefail

# Paperspace notebooks often mount /notebooks with host-side ownership.
# If we are root, fix ownership to NB_UID/NB_GID. If not, print helpful diagnostics.
NB_UID="${NB_UID:-1000}"
NB_GID="${NB_GID:-1000}"

fix_perms() {
  local dir="$1"
  if [ ! -d "$dir" ]; then return 0; fi

  if [ "$(id -u)" = "0" ]; then
    echo "[entrypoint] fixing permissions: ${dir} -> ${NB_UID}:${NB_GID}"
    chown -R "${NB_UID}:${NB_GID}" "${dir}" || true
    chmod -R u+rwX,g+rwX "${dir}" || true
  else
    echo "[entrypoint] running as uid=$(id -u) gid=$(id -g) (not root)."
    echo "[entrypoint] if you cannot write to ${dir}, its ownership is likely mismatched."
    ls -ld "${dir}" || true
  fi
}

fix_perms /notebooks
fix_perms /workspace
fix_perms /opt/forge

# Ensure HOME is set (some notebook launchers override it)
export HOME="${HOME:-/home/${NB_USER:-mambauser}}"

# Execute passed command inside the conda env
exec micromamba run -n pyenv "$@"
