FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

LABEL maintainer="kgrren"

# ------------------------------
# 1. Environment Variables
# ------------------------------
ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    MAMBA_ROOT_PREFIX=/opt/conda \
    # pyenvのbinを先頭に持ってくることで、デフォルトの 'python' や 'jupyter' がこれを指すようにする
    PATH=/opt/conda/envs/pyenv/bin:/opt/conda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    CUDA_HOME=/usr/local/cuda \
    TORCH_CUDA_ARCH_LIST="8.6" \
    FORCE_CUDA="1" \
    PIP_NO_CACHE_DIR=1

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
# 3. Micromamba Setup (参考コードの構造を反映)
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
# 4. Python Environment (pyenv)
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

# 依存関係として必要なパッケージ
RUN micromamba run -n pyenv pip install flash-attn --no-build-isolation
RUN micromamba run -n pyenv pip install sageattention

# ------------------------------
# 6. Configuration & Permissions
# ------------------------------
COPY jupyter_server_config.py /etc/jupyter/jupyter_server_config.py

# Paperspaceが使うディレクトリを事前に作成し権限を付与
RUN mkdir -p /notebooks
WORKDIR /notebooks

COPY scripts/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# ポート開放
EXPOSE 8888

# 参考コード同様、Entrypointを確実に実行
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Paperspaceのデフォルト設定。これがEntrypointの "$@" に渡される
CMD ["jupyter", "lab", "--allow-root", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--ServerApp.token=", "--ServerApp.password=", "--ServerApp.allow_origin='*'"]
