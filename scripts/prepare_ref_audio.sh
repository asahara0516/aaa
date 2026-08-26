#!/usr/bin/env bash
# 録音した自分の声を Irodori-TTS の参照音声として使える形に整える。
#
#   ./scripts/prepare_ref_audio.sh 録音1.m4a 録音2.wav
#
# 処理内容:
#   1. モノラル 16bit WAV に変換（サンプルレートは元のまま）
#   2. 前後の無音をトリム
#   3. 約8秒のクリップに分割（短いクリップ複数が v4-Small の学習条件に合う）
#   4. 合計が上限秒数に収まるところで打ち切り
#
set -euo pipefail

OUT_DIR="${REF_OUT_DIR:-ref}"
SEG_SEC="${REF_SEG_SEC:-8}"        # 1クリップの長さ
MAX_TOTAL="${REF_MAX_TOTAL:-32}"   # 合計の目安（30秒前後で効果が頭打ち・上限は120秒）
NORMALIZE="${REF_NORMALIZE:-0}"    # 1 にすると音量を揃える

for tool in ffmpeg ffprobe; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "エラー: $tool が必要です。'brew install ffmpeg' を実行してください。" >&2; exit 1; }
done

[ $# -ge 1 ] || { echo "使い方: $0 録音ファイル [録音ファイル...]" >&2; exit 1; }

MAX_CLIPS=$(( MAX_TOTAL / SEG_SEC ))
rm -rf "$OUT_DIR"; mkdir -p "$OUT_DIR"

# 前後の無音を削る（-45dB 未満を無音とみなす）
TRIM='silenceremove=start_periods=1:start_duration=0.1:start_threshold=-45dB:detection=peak'
FILTER="${TRIM},areverse,${TRIM},areverse"
[ "$NORMALIZE" = "1" ] && FILTER="${FILTER},loudnorm=I=-18:TP=-2:LRA=11"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

idx=0
total=0
for src in "$@"; do
  [ -f "$src" ] || { echo "スキップ（存在しません）: $src" >&2; continue; }
  echo "==> 処理中: $src"

  ffmpeg -hide_banner -loglevel error -y -i "$src" \
    -ac 1 -c:a pcm_s16le -af "$FILTER" \
    -f segment -segment_time "$SEG_SEC" \
    "$tmp/part_%03d.wav"

  for part in "$tmp"/part_*.wav; do
    [ -e "$part" ] || break
    dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$part")
    # 2秒未満の切れ端は参照音声として役に立たないので捨てる
    if awk "BEGIN{exit !($dur < 2.0)}"; then rm -f "$part"; continue; fi
    idx=$(( idx + 1 ))
    if [ "$idx" -gt "$MAX_CLIPS" ]; then rm -f "$part"; continue; fi
    printf -v dest "%s/ref_%02d.wav" "$OUT_DIR" "$idx"
    mv "$part" "$dest"
    total=$(awk "BEGIN{printf \"%.2f\", $total + $dur}")
    printf '    %s (%.1f秒)\n' "$dest" "$dur"
  done
  rm -f "$tmp"/part_*.wav
done

if [ "$idx" -eq 0 ]; then
  echo "エラー: 使えるクリップが作れませんでした。録音が短すぎるか無音の可能性があります。" >&2
  exit 1
fi

kept=$(( idx > MAX_CLIPS ? MAX_CLIPS : idx ))
echo
printf '==> %s/ に %d クリップ（合計 %.1f秒）を用意しました\n' "$OUT_DIR" "$kept" "$total"
if awk "BEGIN{exit !($total < 15)}"; then
  echo "    ヒント: 合計15秒未満です。録音を足すと声の再現度が上がります（30秒前後が目安）。"
fi
echo "    生成: ./scripts/say.sh \"こんにちは\" $OUT_DIR/*.wav"
