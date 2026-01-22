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
# 3. Micromamba & Python 3.11 + PyYAML (最新の6系を事前導入)
# ------------------------------
RUN set -ex; \
    arch=$(uname -m); \
    if [ "$arch" = "x86_64" ]; then arch="linux-64"; fi; \
    curl -Ls "https://micro.mamba.pm/api/micromamba/${arch}/latest" -o /tmp/micromamba.tar.bz2; \
    tar -xj -C /usr/local/bin/ --strip-components=1 -f /tmp/micromamba.tar.bz2 bin/micromamba; \
    rm /tmp/micromamba.tar.bz2; \
    mkdir -p $MAMBA_ROOT_PREFIX; \
    micromamba shell init -s bash; \
    # Python3.11で確実に動く PyYAML 6.0.1 を conda で先に入れます
    micromamba create -y -n pyenv -c conda-forge python=3.11 pyyaml=6.0.1; \
    micromamba clean -a -y

# ------------------------------
# 4. Install Core ML Libs (PyTorch 2.4.1)
# ------------------------------
RUN micromamba run -n pyenv pip install --no-cache-dir \
    torch==2.4.1+cu124 torchvision==0.19.1+cu124 torchaudio==2.4.1+cu124 \
    --index-url https://download.pytorch.org/whl/cu124

# ------------------------------
# 5. Gradient & Jupyter Tools (ビルドエラーの核心部)
# ------------------------------
# gradient 2.0.6 は PyYAML 5.x を要求してエラーになるため、
# 1. 依存関係を無視して gradient をインストール (--no-deps)
# 2. gradient が必要とする他の主要ライブラリを手動で補完
RUN micromamba run -n pyenv pip install --no-cache-dir \
    jupyterlab==3.6.5 notebook jupyter-server-proxy \
    xformers==0.0.28.post1 \
    ninja

RUN micromamba run -n pyenv pip install --no-cache-dir --no-deps gradient==2.0.6 && \
    micromamba run -n pyenv pip install --no-cache-dir \
    "click<9.0" "requests<3.0" marshmallow attrs

# ------------------------------
# 6. Optimization & Nunchaku (SVDQ)
# ------------------------------
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    mv /root/.local/bin/uv /usr/local/bin/uv

# 1. ビルドに必要な基本パッケージと依存関係を先に一括インストール
RUN micromamba run -n pyenv pip install --no-cache-dir \
    numpy ninja einops accelerate peft diffusers transformers sentencepiece

# 2. A4000 (Ampere / SM 8.6) 向けに最適化して各ライブラリをビルド・インストール
# --no-build-isolation を使うことで、Step 4で入れた Torch 2.4.1 を直接参照させます
RUN export TORCH_CUDA_ARCH_LIST="8.6" && \
    micromamba run -n pyenv pip install --no-cache-dir flash-attn --no-build-isolation && \
    micromamba run -n pyenv pip install --no-cache-dir sageattention && \
    micromamba run -n pyenv pip install --no-cache-dir \
    git+https://github.com/mit-han-lab/nunchaku.git --no-deps --no-build-isolation

# 3. 最後に整合性チェック（ビルド失敗を早期検知するため）
RUN micromamba run -n pyenv python -c "import torch; import nunchaku; import sageattention; print('Optimization Libs Build Success!')"

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
