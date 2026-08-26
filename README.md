# Irodori-TTS セットアップ（Apple Silicon Mac 向け）

[Irodori-TTS](https://github.com/Aratako/Irodori-TTS)（日本語特化のローカルTTS・MITライセンス）を
MacBook で動かし、**自分の声で読み上げる**ためのセットアップ一式です。

対象環境: Apple Silicon Mac / メモリ16GB以上推奨（M5・24GB で快適に動作する構成）

---

## 1. セットアップ

```bash
git clone <このリポジトリ> && cd aaa
./scripts/setup_mac.sh
```

やっていること:

- Apple Silicon かどうか、メモリ量のチェック
- `uv`（Pythonパッケージマネージャ）が無ければ導入
- Irodori-TTS を `~/Irodori-TTS` に取得
- `uv sync --extra cpu` で依存関係を解決
  ※ macOS では CUDA 用ホイールを避けるため `cpu` を指定します。この torch は
    Apple Silicon の GPU（MPS）を利用できるので、CPU実行になるわけではありません
- PyTorch から MPS が見えているかを確認

インストール先を変えたい場合は `IRODORI_DIR=/path/to/dir ./scripts/setup_mac.sh`。

---

## 2. 自分の声を用意する

仕上がりの大半はここで決まります。

**録音のコツ**

| 項目 | 推奨 |
|---|---|
| 長さ | 5〜10秒のクリップを4〜6本、**合計30秒前後** |
| 上限 | 合計120秒（超過分は自動で切られる） |
| 環境 | 静かな部屋。反響・エアコン音・BGMは声質として一緒に学習される |
| 話し方 | 本番の用途に寄せる（ナレーション用途ならナレーション調で） |
| 書き起こし | **不要**。参照音声から話者性が自動抽出される |

**録音する**

```bash
brew install ffmpeg          # 初回のみ
./scripts/record.sh          # 40秒の一発録り → rec.wav
```

`./scripts/record.sh 60 voice.wav` で秒数と出力先を変更、`--list` でマイク一覧、
`REC_DEVICE=1` で別のマイクを指定できます。初回はターミナルにマイクへのアクセス許可が必要です。

QuickTime Player やボイスメモで録った .m4a をそのまま渡しても構いません（変換は不要）。

**参照音声に整える**

```bash
./scripts/prepare_ref_audio.sh rec.wav
```

モノラル16bit WAVへの変換、前後の無音トリム、約8秒ごとの分割、
合計秒数の打ち切りまでを行い、`ref/` に `ref_01.wav`… として出力します。

調整用の環境変数: `REF_OUT_DIR` / `REF_SEG_SEC` / `REF_MAX_TOTAL` / `REF_NORMALIZE=1`（音量を揃える）

---

## 3. 生成する

### Web UI（おすすめ・パラメータを触りながら試せる）

```bash
./scripts/run_webui.sh          # http://127.0.0.1:7860
```

### コマンドライン

```bash
./scripts/say.sh "こんにちは、テストです。" ref/*.wav
```

生成物は `~/Irodori-TTS/outputs/` に保存され、`afplay` で自動再生されます。
モデルを変えたい場合は `IRODORI_CHECKPOINT=Aratako/Irodori-TTS-v3-2.5B ./scripts/say.sh ...`。

初回実行時にモデル（数GB）のダウンロードが走ります。

---

## 4. 似ていないときの調整

| パラメータ | 既定値 | 効果 |
|---|---|---|
| Speaker Strength | 5.0 | 参照音声への忠実度。**似ていないときはまずここを上げる** |
| Text Strength | 3.0 | テキストへの忠実度。上げすぎると読みは正確だが硬くなる |

それでも足りなければ **Speaker Inversion**（話者埋め込みトークン16個・12Kパラメータだけを学習する方式、
成果物は約49KB）が使えます。LoRA（17Mパラメータ）より遥かに軽く、一度作れば参照音声を持ち歩かずに
自分の声を呼び出せます。`~/Irodori-TTS/train.py` と `configs/` を参照してください。

---

## Mac特有の注意点

1. **fp32 のまま使う** — MPS では bf16 に落とすとむしろ遅くなる検証結果が出ています。「軽量化」で精度を下げないこと
2. **Docker を使わない** — ネイティブ実行に比べて大幅に遅くなります
3. **モデルとコーデックの両方を MPS に載せる** — 片方が CPU のままだと転送で損をします
4. 起動スクリプトは `PYTORCH_ENABLE_MPS_FALLBACK=1` を設定済み。MPS 未実装の演算に当たっても
   CPU にフォールバックして継続します

## 参考

- [Irodori-TTS (GitHub)](https://github.com/Aratako/Irodori-TTS)
- [Mac MPS で Irodori-TTS をチューニングして2.72倍高速化 / bf16 では遅くなった](https://zenn.dev/yoshitetsu/articles/e616831f96b44a)
- [音声ファイルよりも軽い埋め込みだけで声を学習する（Speaker Inversion）](https://zenn.dev/platina/articles/speaker-inversion)
