#!/bin/bash
set -e

# Paperspaceがマウントするディレクトリの権限を、起動時に強制開放する
# これにより "Error creating file" が解消されます
if [ -d "/notebooks" ]; then
    chmod 777 /notebooks
fi

# Micromamba環境の有効化（パスを通すための設定）
eval "$(micromamba shell hook --shell bash)"
micromamba activate pyenv

# Paperspaceのデフォルトコマンド（Jupyter起動）を実行する
exec "$@"
