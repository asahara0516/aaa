#!/usr/bin/env bash
# 台本を1行ずつ自分の声で書き出す（1行 = 1場面 = 1ファイル）
#
#   ./motion/narrate.sh ref/*.wav
#   NARRATION=motion/narration.txt OUT_DIR=outputs/ohana ./motion/narrate.sh ref/*.wav
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="${NARRATION:-$ROOT/motion/narration.txt}"
OUT_DIR="${OUT_DIR:-outputs/ohana}"

[ $# -ge 1 ] || { echo "使い方: $0 参照音声.wav [参照音声2.wav ...]" >&2; exit 1; }

n=0
while IFS= read -r line || [ -n "$line" ]; do
  [ -n "$line" ] || continue
  n=$((n + 1))
  out="$OUT_DIR/$(printf '%02d' "$n").wav"
  echo "==> [$n] $line"
  IRODORI_OUT="$out" "$ROOT/scripts/say.sh" "$line" "$@"
done < "$SCRIPT"

echo "==> $n 本を $OUT_DIR に書き出しました（Irodori-TTS のフォルダ内）"
