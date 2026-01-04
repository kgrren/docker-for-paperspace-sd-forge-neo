# ----------------------------------------------------------------------------
# Base Image: CUDA 12.4.1 for Paperspace
# ----------------------------------------------------------------------------
FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

LABEL maintainer="kgrren"

# ------------------------------
# 1. Environment Variables
# ------------------------------
ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    MAMBA_ROOT_PREFIX=/opt/conda \
    # パス設定：pyenv環境を最優先に。これでデフォルトコマンドがこの環境を叩くようになります
    PATH=/opt/conda/envs/pyenv/bin:/opt/conda/bin:$PATH \
    CUDA_HOME=/usr/local/cuda \
    TORCH_CUDA_ARCH_LIST="8.6" \
    FORCE_CUDA="1"

# ------------------------------
# 2. System Packages
# ------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget curl git nano vim unzip zip \
    libgl1 libglib2.0-0 libgoogle-perftools4 \
    build-essential python3-dev \
    ffmpeg bzip2 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------
# 3. Micromamba & Python 3.11
# ------------------------------
RUN set -ex; \
    arch=$(uname -m); \
    if [ "$arch" = "x86_64" ]; then arch="linux-64"; fi; \
    if [ "$arch" = "aarch64" ]; then arch="linux-aarch64"; fi; \
    curl -Ls "https://micro.mamba.pm/api/micromamba/${arch}/latest" -o /tmp/micromamba.tar.bz2; \
    tar -xj -C /usr/local/bin/ --strip-components=1 -f /tmp/micromamba.tar.bz2 bin/micromamba; \
    rm /tmp/micromamba.tar.bz2; \
    mkdir -p $MAMBA_ROOT_PREFIX; \
    micromamba shell init -s bash; \
    micromamba create -y -n pyenv -c conda-forge python=3.11; \
    micromamba clean -a -y

# ------------------------------
# 4. Install Core ML Libs (pyenv環境へ)
# ------------------------------
RUN micromamba run -n pyenv pip install \
    torch==2.4.1+cu124 torchvision==0.19.1+cu124 torchaudio==2.4.1+cu124 \
    --index-url https://download.pytorch.org/whl/cu124

RUN micromamba run -n pyenv pip install \
    jupyterlab notebook jupyter-server-proxy \
    xformers==0.0.28.post1 \
    ninja

# ------------------------------
# 5. Build Tools & Optimization
# ------------------------------
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    mv /root/.local/bin/uv /usr/local/bin/uv

RUN micromamba run -n pyenv pip install flash-attn --no-build-isolation
RUN micromamba run -n pyenv pip install sageattention

# ------------------------------
# 6. Final Setup
# ------------------------------
COPY jupyter_server_config.py /etc/jupyter/jupyter_server_config.py

WORKDIR /notebooks
COPY scripts/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# ポート開放
EXPOSE 8888

# 参考コードに合わせた Entrypoint 形式
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Paperspaceのデフォルト設定に干渉しないよう、CMDは最小限にする
# これにより、Paperspace側で指定されるデフォルトコマンドが正しく引き継がれます
CMD ["jupyter", "lab", "--allow-root", "--ip=0.0.0.0", "--port=8888", "--no-browser"]
