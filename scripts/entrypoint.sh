#!/bin/bash
set -e

# Paperspaceの /notebooks 権限を強制修正
# これが実行されないと Jupyter 上でファイルが作れません
if [ -d "/notebooks" ]; then
    echo "Setting permissions for /notebooks..."
    chmod 777 /notebooks
    # 既存のファイルも含めて権限を広げる（必要に応じて）
    chown -R root:root /notebooks
fi

# Micromamba環境の有効化
eval "$(micromamba shell hook --shell bash)"
micromamba activate pyenv

# デフォルト環境として認識させるための変数
export CONDA_PREFIX=$MAMBA_ROOT_PREFIX/envs/pyenv
export CONDA_DEFAULT_ENV=pyenv

exec "$@"
