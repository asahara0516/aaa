#!/usr/bin/env bash
# Irodori-TTS を Apple Silicon Mac にセットアップする
set -euo pipefail

REPO_URL="https://github.com/Aratako/Irodori-TTS.git"
INSTALL_DIR="${IRODORI_DIR:-$HOME/Irodori-TTS}"

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m警告:\033[0m %s\n' "$*"; }
die()   { printf '\033[1;31mエラー:\033[0m %s\n' "$*" >&2; exit 1; }

# --- 1. 環境チェック -------------------------------------------------------
[ "$(uname -s)" = "Darwin" ] || die "このスクリプトは macOS 専用です（検出: $(uname -s)）"

ARCH="$(uname -m)"
if [ "$ARCH" != "arm64" ]; then
  warn "Apple Silicon ではありません（$ARCH）。CPU実行のみになり、実用的な速度は出ません。"
  read -r -p "それでも続けますか? [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]] || exit 1
fi

MEM_GB=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
info "検出: $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "$ARCH") / ${MEM_GB}GB"
if [ "$MEM_GB" -lt 16 ]; then
  warn "メモリ ${MEM_GB}GB は推奨（16GB以上）を下回ります。1文の生成に数分かかる可能性があります。"
fi

command -v git >/dev/null 2>&1 || die "git が見つかりません。'xcode-select --install' を実行してください。"

# --- 2. uv の用意 ----------------------------------------------------------
if ! command -v uv >/dev/null 2>&1; then
  info "uv が見つかりません。インストールします。"
  if command -v brew >/dev/null 2>&1; then
    brew install uv
  else
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi
fi
command -v uv >/dev/null 2>&1 || die "uv のインストールに失敗しました。ターミナルを開き直して再実行してください。"
info "uv: $(uv --version)"

# --- 3. リポジトリの取得 ---------------------------------------------------
if [ -d "$INSTALL_DIR/.git" ]; then
  info "既存のインストールを更新します: $INSTALL_DIR"
  git -C "$INSTALL_DIR" pull --ff-only
else
  info "クローンします: $INSTALL_DIR"
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

# --- 4. 依存関係の解決 -----------------------------------------------------
# macOS では CUDA ホイールを避けるため cpu extra を使う。
# この torch は Apple Silicon の GPU (MPS) を利用できる。
info "依存関係を解決します（初回は数分かかります）"
cd "$INSTALL_DIR"
uv sync --extra cpu

# --- 5. 動作確認 -----------------------------------------------------------
info "PyTorch と MPS の状態を確認します"
uv run --no-sync python - <<'PY'
import torch
print(f"  torch      : {torch.__version__}")
print(f"  MPS 利用可 : {torch.backends.mps.is_available()}")
print(f"  MPS ビルド : {torch.backends.mps.is_built()}")
if not torch.backends.mps.is_available():
    print("  → MPS が使えません。CPU実行になり非常に遅くなります。")
PY

cat <<MSG

$(info "セットアップ完了")

  インストール先: $INSTALL_DIR

  次の手順:
    1. Web UI を起動        ./scripts/run_webui.sh
    2. 参照音声を整える     ./scripts/prepare_ref_audio.sh 録音.wav
    3. コマンドラインで生成 下記参照

  初回起動時にモデル（数GB）のダウンロードが走ります。

MSG
