# ----------------------------------------------------------------------------
# Base Image: CUDA 12.4.1 for PyTorch 2.4+ compatibility
# ----------------------------------------------------------------------------
FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

LABEL maintainer="YourName <your@email.com>"

# ------------------------------
# Environment Variables
# ------------------------------
ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    MAMBA_ROOT_PREFIX=/opt/conda \
    PATH=/opt/conda/bin:$PATH \
    # Forge Neo Speed Optimizations
    CUDA_HOME=/usr/local/cuda \
    TORCH_CUDA_ARCH_LIST="8.6" \
    # A4000 is Ampere (8.6)
    FORCE_CUDA="1"

# ------------------------------
# System Packages
# ------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget curl git nano vim unzip zip \
    libgl1 libglib2.0-0 libgoogle-perftools4 \
    build-essential python3-dev \
    ffmpeg \
    bzip2 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------
# Install Micromamba & Python 3.11
# ------------------------------
RUN set -ex; \
    arch=$(uname -m); \
    if [ "$arch" = "x86_64" ]; then arch="linux-64"; fi; \
    if [ "$arch" = "aarch64" ]; then arch="linux-aarch64"; fi; \
    curl -Ls "https://micro.mamba.pm/api/micromamba/${arch}/latest" -o /tmp/micromamba.tar.bz2; \
    tar -xj -C /usr/local/bin/ --strip-components=1 -f /tmp/micromamba.tar.bz2 bin/micromamba; \
    rm /tmp/micromamba.tar.bz2; \
    \
    # 1. Root Prefix ディレクトリ作成
    mkdir -p $MAMBA_ROOT_PREFIX; \
    \
    # 2. shell init を実行（-pを使わず環境変数を利用）
    export MAMBA_ROOT_PREFIX=$MAMBA_ROOT_PREFIX; \
    micromamba shell init -s bash; \
    \
    # 3. Python 3.11 環境作成
    # -p ではなく -n (name) または --prefix を使用しますが、
    # ここでは $MAMBA_ROOT_PREFIX 自体をベース環境とするために --prefix を使用します
    micromamba create -y --prefix $MAMBA_ROOT_PREFIX -c conda-forge python=3.11; \
    micromamba clean -a -y

# ------------------------------
# Install Core Python Libs & Jupyter
# ------------------------------
# Pytorch 2.4.1 (matching Forge Neo recommendation)
RUN micromamba run -p $MAMBA_ROOT_PREFIX pip install \
    torch==2.4.1+cu124 torchvision==0.19.1+cu124 torchaudio==2.4.1+cu124 \
    --index-url https://download.pytorch.org/whl/cu124

RUN micromamba run -p $MAMBA_ROOT_PREFIX pip install \
    jupyterlab notebook jupyter-server-proxy \
    xformers==0.0.28.post1 \
    ninja

# ------------------------------
# Install 'uv' (Forge Neo Requirement)
# ------------------------------
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    mv /root/.local/bin/uv /usr/local/bin/uv

# ------------------------------
# Install Optimization Libs (FlashAttention / SageAttention)
# ------------------------------
# Flash Attention 2 (Takes time to build, so we do it in docker build)
RUN micromamba run -p $MAMBA_ROOT_PREFIX pip install flash-attn --no-build-isolation

# SageAttention (Optional but recommended by Neo)
RUN micromamba run -p $MAMBA_ROOT_PREFIX pip install sageattention

# ------------------------------
# Jupyter Server Proxy Configuration
# ------------------------------
# Copy config to global jupyter config dir so it persists
COPY jupyter_server_config.py /etc/jupyter/jupyter_server_config.py

# ------------------------------
# Entrypoint & Workspace Setup
# ------------------------------
WORKDIR /notebooks
COPY scripts/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose Jupyter Port
EXPOSE 8888

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["jupyter", "lab", "--allow-root", "--ip=0.0.0.0", "--port=8888", "--no-browser"]
