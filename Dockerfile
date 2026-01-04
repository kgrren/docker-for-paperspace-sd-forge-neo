# ----------------------------------------------------------------------------
# Base Image: CUDA 12.4.1 for Paperspace (A4000 Optimized)
# ----------------------------------------------------------------------------
FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

LABEL maintainer="kgrren"

# ------------------------------
# 1. Environment Variables
# ------------------------------
ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    MAMBA_ROOT_PREFIX=/opt/conda \
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
    ffmpeg \
    bzip2 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------
# 3. Micromamba & Python 3.11 + PyYAML (Pre-built)
# ------------------------------
RUN set -ex; \
    arch=$(uname -m); \
    if [ "$arch" = "x86_64" ]; then arch="linux-64"; fi; \
    curl -Ls "https://micro.mamba.pm/api/micromamba/${arch}/latest" -o /tmp/micromamba.tar.bz2; \
    tar -xj -C /usr/local/bin/ --strip-components=1 -f /tmp/micromamba.tar.bz2 bin/micromamba; \
    rm /tmp/micromamba.tar.bz2; \
    mkdir -p $MAMBA_ROOT_PREFIX; \
    micromamba shell init -s bash; \
    # PyYAML を conda で入れることで、後のビルドエラーを物理的に回避します
    micromamba create -y -n pyenv -c conda-forge python=3.11 pyyaml; \
    micromamba clean -a -y

# ------------------------------
# 4. Install Core ML Libs (PyTorch 2.4.1)
# ------------------------------
RUN micromamba run -n pyenv pip install --no-cache-dir \
    torch==2.4.1+cu124 torchvision==0.19.1+cu124 torchaudio==2.4.1+cu124 \
    --index-url https://download.pytorch.org/whl/cu124

# ------------------------------
# 5. Gradient & Jupyter Tools
# ------------------------------
# --only-binary :all を指定することで、PyYAML等の古いソースビルドを強制的に拒否し、
# すでに conda で入っている PyYAML を利用させます。
RUN micromamba run -n pyenv pip install --no-cache-dir --only-binary :all: \
    jupyterlab==3.6.5 notebook jupyter-server-proxy \
    gradient==2.0.6 \
    xformers==0.0.28.post1 \
    ninja

# ------------------------------
# 6. Optimization & Nunchaku (SVDQ)
# ------------------------------
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    mv /root/.local/bin/uv /usr/local/bin/uv

# SageAttention & FlashAttention
RUN micromamba run -n pyenv pip install --no-cache-dir flash-attn --no-build-isolation
RUN micromamba run -n pyenv pip install --no-cache-dir sageattention

# Nunchaku のインストール
RUN micromamba run -n pyenv pip install --no-cache-dir nunchaku --no-build-isolation

# ------------------------------
# 7. Final Setup
# ------------------------------
COPY jupyter_server_config.py /etc/jupyter/jupyter_server_config.py

WORKDIR /notebooks
COPY scripts/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh
RUN mkdir -p /tmp/sd/models

EXPOSE 8888 7860

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["jupyter", "lab", \
     "--allow-root", \
     "--ip=0.0.0.0", \
     "--port=8888", \
     "--no-browser", \
     "--ServerApp.trust_xheaders=True", \
     "--ServerApp.disable_check_xsrf=False", \
     "--ServerApp.allow_remote_access=True", \
     "--ServerApp.allow_origin='*'", \
     "--ServerApp.allow_credentials=True"]
