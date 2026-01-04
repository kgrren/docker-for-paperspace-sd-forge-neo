#!/bin/bash
set -e

# ----------------------------------------------------------------
# 1. Fix Permissions for Paperspace /notebooks mount
# ----------------------------------------------------------------
# Paperspaceのマウントボリュームは権限が厳しい場合があるため、
# 起動時に強制的に全ユーザー書き込み可能に変更する。
if [ -d "/notebooks" ]; then
    chmod 777 /notebooks
fi

# ----------------------------------------------------------------
# 2. Activate Micromamba Environment (pyenv)
# ----------------------------------------------------------------
# DockerfileでPATHは通しているが、念のためシェル初期化とactivateを行う
eval "$(micromamba shell hook --shell bash)"
micromamba activate pyenv

# ----------------------------------------------------------------
# 3. Execute the passed command (Jupyter Lab)
# ----------------------------------------------------------------
# ここでPaperspaceのデフォルトコマンド(CMD)が実行される
exec "$@"
