#!/usr/bin/env bash
# マイクから一発録りして WAV で保存する（macOS 専用）
#
#   ./scripts/record.sh              40秒録音して rec.wav に保存
#   ./scripts/record.sh 60 voice.wav 60秒録音して voice.wav に保存
#   ./scripts/record.sh --list       マイクの一覧を表示
#
set -euo pipefail

DEVICE="${REC_DEVICE:-0}"   # マイクのインデックス（--list で確認）

[ "$(uname -s)" = "Darwin" ] || { echo "エラー: macOS 専用です。" >&2; exit 1; }
command -v ffmpeg >/dev/null 2>&1 || {
  echo "エラー: ffmpeg が必要です。'brew install ffmpeg' を実行してください。" >&2; exit 1; }

if [ "${1:-}" = "--list" ]; then
  echo "==> 利用可能な入力デバイス（AVFoundation audio devices の番号を使います）"
  ffmpeg -hide_banner -f avfoundation -list_devices true -i "" 2>&1 | sed -n '/AVFoundation/,$p'
  echo
  echo "    別のマイクを使う場合: REC_DEVICE=1 ./scripts/record.sh"
  exit 0
fi

DURATION="${1:-40}"
OUTPUT="${2:-rec.wav}"

case "$DURATION" in
  ''|*[!0-9]*) echo "エラー: 秒数は整数で指定してください（例: $0 40 rec.wav）" >&2; exit 1 ;;
esac

if [ -e "$OUTPUT" ]; then
  read -r -p "$OUTPUT は既に存在します。上書きしますか? [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]] || exit 1
fi

cat <<MSG
==> ${DURATION}秒間録音して $OUTPUT に保存します（デバイス $DEVICE）

    ・口から20〜30cm離れて、普段の話し方で読んでください
    ・途中で終わりたくなったら Ctrl+C（そこまでの録音は保存されます）
    ・初回はマイクへのアクセス許可を求められます。許可してから録り直してください

MSG

for i in 3 2 1; do printf '\r    %d 秒後に開始...' "$i"; sleep 1; done
printf '\r    録音中。話してください。            \n\n'

# Ctrl+C で止めてもファイルを正しく閉じるため、ffmpeg に SIGINT を渡す
ffmpeg -hide_banner -loglevel warning -y \
  -f avfoundation -i ":${DEVICE}" \
  -ac 1 -c:a pcm_s16le \
  -t "$DURATION" "$OUTPUT" || true

[ -s "$OUTPUT" ] || { echo "エラー: 録音できませんでした。'$0 --list' でデバイスを確認してください。" >&2; exit 1; }

dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUTPUT")
printf '\n==> 保存しました: %s (%.1f秒)\n' "$OUTPUT" "$dur"
echo "    確認: afplay $OUTPUT"
echo "    次へ: ./scripts/prepare_ref_audio.sh $OUTPUT"
