#!/bin/bash
set -e

# micromamba環境をロード
eval "$(micromamba shell hook --shell bash)"
micromamba activate base

# ユーザー指定のコマンドを実行 (通常は jupyter lab)
exec "$@"
