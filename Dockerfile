# syntax=docker/dockerfile:1

# Paperspace Gradient custom container requirements:
# - Image must include Python and JupyterLab
# - Jupyter must listen on 0.0.0.0:8888
# - /notebooks is the expected working directory

ARG CUDA_IMAGE=nvidia/cuda:12.3.2-cudnn9-runtime-ubuntu22.04
FROM ${CUDA_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC

# ------------------------------
# OS packages
# ------------------------------
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates curl git wget \
      ffmpeg \
      tini gosu \
      bash \
      software-properties-common \
      build-essential pkg-config \
      libgl1 libglib2.0-0 libsm6 libxext6 libxrender1; \
    rm -rf /var/lib/apt/lists/*

# ------------------------------
# Python 3.11 (Forge Neo recommends 3.11.x)
# ------------------------------
RUN set -eux; \
    add-apt-repository ppa:deadsnakes/ppa; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      python3.11 python3.11-venv python3.11-dev \
      python3-pip; \
    rm -rf /var/lib/apt/lists/*; \
    python3.11 -m pip install --no-cache-dir --upgrade pip setuptools wheel

# Prefer python3 -> python3.11
RUN set -eux; \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1; \
    python3 --version

# ------------------------------
# JupyterLab + server proxy (Launcher integration)
# ------------------------------
RUN set -eux; \
    python3 -m pip install --no-cache-dir \
      jupyterlab==4.* \
      jupyter-server-proxy==4.* \
      jupyterlab-git==0.50.* \
      notebook==7.*

# ------------------------------
# Forge Neo source (default repo/ref can be overridden at build time)
# ------------------------------
ARG FORGE_REPO=https://github.com/Haoming02/sd-webui-forge-classic.git
ARG FORGE_REF=neo
ENV FORGE_HOME=/opt/sd-webui-forge-neo

RUN set -eux; \
    mkdir -p /opt; \
    git clone --depth 1 --branch "${FORGE_REF}" "${FORGE_REPO}" "${FORGE_HOME}"

# ------------------------------
# Runtime user strategy
# - Paperspace runtime may attempt to switch to user "gradient"
#   BEFORE our entrypoint runs, so we must create it at build time.
# - /notebooks may be mounted with arbitrary ownership; entrypoint will
#   try to align permissions when running as root.
# ------------------------------
ENV NB_USER=gradient \
    NB_UID=1000 \
    NB_GID=1000

# Ensure "gradient" user exists in /etc/passwd (Paperspace expectation)
# Keep it robust if UID/GID 1000 already exists in the base image.
RUN set -eux; \
    if ! getent group "${NB_USER}" >/dev/null 2>&1; then \
      if getent group "${NB_GID}" >/dev/null 2>&1; then \
        # GID already taken -> reuse that existing group name
        EXISTING_GROUP="$(getent group "${NB_GID}" | cut -d: -f1)"; \
        echo "GID ${NB_GID} already exists as group ${EXISTING_GROUP}, will use it"; \
      else \
        groupadd -g "${NB_GID}" "${NB_USER}"; \
      fi; \
    fi; \
    if ! id -u "${NB_USER}" >/dev/null 2>&1; then \
      if getent passwd "${NB_UID}" >/dev/null 2>&1; then \
        # UID already taken -> we still must create name "gradient".
        # Create user with a free UID.
        useradd -m -s /bin/bash "${NB_USER}"; \
      else \
        useradd -m -s /bin/bash -u "${NB_UID}" -g "${NB_GID}" "${NB_USER}"; \
      fi; \
    fi

# Precreate common paths (ownership fixed at runtime / mount time)
RUN set -eux; \
    mkdir -p /notebooks /workspace /opt/conda; \
    chmod 777 /notebooks /workspace

# ------------------------------
# Config + scripts
# ------------------------------
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/start-jupyter.sh /usr/local/bin/start-jupyter.sh
COPY scripts/start-forge.sh /usr/local/bin/start-forge.sh
COPY jupyter_server_config.py /etc/jupyter/jupyter_server_config.py

RUN set -eux; \
    chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/start-jupyter.sh /usr/local/bin/start-forge.sh

EXPOSE 8888 7860

WORKDIR /notebooks

# tini as PID1, then our entrypoint (which will exec start-jupyter by default)
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["/usr/local/bin/start-jupyter.sh"]
