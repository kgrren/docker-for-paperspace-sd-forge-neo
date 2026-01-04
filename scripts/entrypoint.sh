#!/usr/bin/env bash
set -euo pipefail

# Paperspace may start the container as an arbitrary UID/GID.
# We want /notebooks to be writable and run Jupyter/Forge as a non-root user
# matching the mounted volume ownership when possible.

NB_USER="${NB_USER:-gradient}"
NB_UID="${NB_UID:-1000}"
NB_GID="${NB_GID:-1000}"

NOTEBOOK_DIR="${NOTEBOOK_DIR:-/notebooks}"

# If /notebooks exists, prefer its ownership
if [ -d "${NOTEBOOK_DIR}" ]; then
  VOL_UID="$(stat -c '%u' "${NOTEBOOK_DIR}" || echo "${NB_UID}")"
  VOL_GID="$(stat -c '%g' "${NOTEBOOK_DIR}" || echo "${NB_GID}")"
  NB_UID="${VOL_UID}"
  NB_GID="${VOL_GID}"
fi

ensure_user() {
  if ! getent group "${NB_GID}" >/dev/null 2>&1; then
    groupadd -g "${NB_GID}" "${NB_USER}" >/dev/null 2>&1 || true
  fi
  if ! id -u "${NB_USER}" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -u "${NB_UID}" -g "${NB_GID}" "${NB_USER}" >/dev/null 2>&1 || true
  fi
}

fix_perms() {
  local d="$1"
  [ -d "$d" ] || return 0
  # If we're root, try to make it writable by NB_UID/NB_GID.
  if [ "$(id -u)" = "0" ]; then
    chown -R "${NB_UID}:${NB_GID}" "$d" || true
    chmod -R u+rwX,g+rwX "$d" || true
  fi
}

if [ "$(id -u)" = "0" ]; then
  ensure_user
  fix_perms "${NOTEBOOK_DIR}"
  fix_perms "/workspace"
  # Drop privileges
  exec gosu "${NB_USER}" "$@"
else
  # Already non-root; just run
  exec "$@"
fi
