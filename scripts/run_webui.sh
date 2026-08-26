#!/usr/bin/env bash
# Irodori-TTS の Web UI を起動する
set -euo pipefail

INSTALL_DIR="${IRODORI_DIR:-$HOME/Irodori-TTS}"
PORT="${IRODORI_PORT:-7860}"

[ -d "$INSTALL_DIR" ] || { echo "エラー: $INSTALL_DIR がありません。先に scripts/setup_mac.sh を実行してください。" >&2; exit 1; }

cd "$INSTALL_DIR"

# MPS で未実装の演算に当たった場合に CPU へ落として続行する（クラッシュ回避）
export PYTORCH_ENABLE_MPS_FALLBACK=1

echo "==> http://127.0.0.1:${PORT} で起動します（停止は Ctrl+C）"
exec uv run --no-sync python gradio_app.py \
  --server-name 127.0.0.1 \
  --server-port "$PORT"
