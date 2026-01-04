# ----------------------------------------------------------------------------
# Paperspace Gradient Notebook image for Stable Diffusion Forge Neo
# - Base: NVIDIA CUDA 12.4 + cuDNN (Ubuntu 22.04)
# - Env manager: micromamba
# - Default: launches JupyterLab on port 8888 (Forge can be started on 7860)
# ----------------------------------------------------------------------------
FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

# BuildKit platform args
ARG TARGETARCH
ARG TARGETOS


LABEL maintainer="kgrren"

# ------------------------------
# Build args / runtime env
# ------------------------------
ARG PYTHON_VERSION=3.11
ARG NB_USER=mambauser
ARG NB_UID=1000
ARG NB_GID=1000

# Forge source (override as needed)
ARG FORGE_REPO=https://github.com/lllyasviel/stable-diffusion-webui-forge.git
ARG FORGE_REF=master

# Optional extra deps that may fail to build on some setups
ARG INSTALL_FLASH_ATTN=0
ARG INSTALL_SAGEATTENTION=0

ENV DEBIAN_FRONTEND=noninteractive     SHELL=/bin/bash     MAMBA_ROOT_PREFIX=/opt/conda     MAMBA_USER=${NB_USER}     NB_USER=${NB_USER}     NB_UID=${NB_UID}     NB_GID=${NB_GID}     CUDA_HOME=/usr/local/cuda     PIP_NO_CACHE_DIR=1     PYTHONDONTWRITEBYTECODE=1     PYTHONUNBUFFERED=1     NVIDIA_VISIBLE_DEVICES=all     NVIDIA_DRIVER_CAPABILITIES=compute,utility

# Put micromamba + env bin on PATH (env path added after env creation too)
ENV PATH=/opt/conda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# ------------------------------
# OS packages
# ------------------------------
RUN set -eux;     apt-get update;     apt-get install -y --no-install-recommends       ca-certificates curl wget git       bzip2 xz-utils       tini       build-essential pkg-config       libgl1 libglib2.0-0       iproute2       openssh-client     ;     rm -rf /var/lib/apt/lists/*

# ------------------------------
# micromamba
# ------------------------------
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) mamba_arch="linux-64" ;; \
      arm64) mamba_arch="linux-aarch64" ;; \
      *) echo "Unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -Ls "https://micro.mamba.pm/api/micromamba/${mamba_arch}/latest" | tar -xvj -C /usr/local/bin --strip-components=1 bin/micromamba; \
    chmod +x /usr/local/bin/micromamba; \
    /usr/local/bin/micromamba --version

# ------------------------------
# Create a non-root user (Paperspace-friendly)
# ------------------------------
RUN set -eux;     groupadd --gid "${NB_GID}" "${NB_USER}" || true;     useradd  --uid "${NB_UID}" --gid "${NB_GID}" -m -s /bin/bash "${NB_USER}" || true;     mkdir -p /notebooks /workspace /opt/forge /opt/conda;     chown -R "${NB_UID}:${NB_GID}" /notebooks /workspace /opt/forge /opt/conda

# ------------------------------
# Create conda env + Jupyter tooling
# ------------------------------
RUN set -eux;     micromamba create -y -n pyenv -c conda-forge       "python=${PYTHON_VERSION}"       pip       jupyterlab       jupyter-server-proxy       nodejs       git     ;     micromamba clean -a -y

# Ensure env bin is preferred
ENV PATH=/opt/conda/envs/pyenv/bin:/opt/conda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# ------------------------------
# uv (optional but handy)
# ------------------------------
RUN set -eux;     curl -LsSf https://astral.sh/uv/install.sh | sh;     mv /root/.local/bin/uv /usr/local/bin/uv || true;     uv --version || true

# ------------------------------
# Fetch Forge sources (kept in image; you can also mount over /opt/forge)
# ------------------------------
RUN set -eux;     git clone --depth 1 --branch "${FORGE_REF}" "${FORGE_REPO}" /opt/forge || (       echo "WARN: failed to clone Forge (repo/ref). Build will continue; mount your own sources at /opt/forge." >&2;       mkdir -p /opt/forge     );     chown -R "${NB_UID}:${NB_GID}" /opt/forge

# ------------------------------
# Optional performance deps (best-effort)
# ------------------------------
RUN set -eux;     if [ "${INSTALL_FLASH_ATTN}" = "1" ]; then       micromamba run -n pyenv python -m pip install --upgrade pip;       micromamba run -n pyenv pip install flash-attn --no-build-isolation || echo "WARN: flash-attn install failed (continuing)";     fi;     if [ "${INSTALL_SAGEATTENTION}" = "1" ]; then       micromamba run -n pyenv pip install sageattention || echo "WARN: sageattention install failed (continuing)";     fi

# ------------------------------
# Jupyter configuration + helper scripts
# ------------------------------
COPY jupyter_server_config.py /etc/jupyter/jupyter_server_config.py
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/start-forge.sh /usr/local/bin/start-forge.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/start-forge.sh

# ------------------------------
# Runtime
# ------------------------------
WORKDIR /notebooks
EXPOSE 8888 7860

# Run as non-root by default (Paperspace expects this)
USER ${NB_USER}

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--ServerApp.token=", "--ServerApp.password=", "--ServerApp.allow_origin=*"]
