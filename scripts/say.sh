#!/usr/bin/env bash
# 参照音声（自分の声）でテキストを読み上げる
#
#   ./scripts/say.sh "読み上げたいテキスト" ref/*.wav
#
set -euo pipefail

INSTALL_DIR="${IRODORI_DIR:-$HOME/Irodori-TTS}"
CHECKPOINT="${IRODORI_CHECKPOINT:-Aratako/Irodori-TTS-v4.1-Small}"

if [ $# -lt 2 ]; then
  cat >&2 <<USAGE
使い方: $0 "テキスト" 参照音声.wav [参照音声2.wav ...]

環境変数:
  IRODORI_CHECKPOINT  使用モデル (既定: $CHECKPOINT)
  IRODORI_OUT         出力先     (既定: outputs/<日時>.wav)
USAGE
  exit 1
fi

TEXT="$1"; shift

# 参照音声を絶対パスに直す（cd するため）
REFS=()
for f in "$@"; do
  [ -f "$f" ] || { echo "エラー: 参照音声が見つかりません: $f" >&2; exit 1; }
  REFS+=("$(cd "$(dirname "$f")" && pwd)/$(basename "$f")")
done

OUT="${IRODORI_OUT:-outputs/$(date +%Y%m%d-%H%M%S).wav}"

cd "$INSTALL_DIR"
mkdir -p "$(dirname "$OUT")"
export PYTORCH_ENABLE_MPS_FALLBACK=1

uv run --no-sync python infer.py \
  --hf-checkpoint "$CHECKPOINT" \
  --text "$TEXT" \
  --ref-wavs "${REFS[@]}" \
  --output-wav "$OUT"

echo "==> 生成しました: $INSTALL_DIR/$OUT"
command -v afplay >/dev/null 2>&1 && afplay "$OUT" || true
