# OGP 画像（docs/ogp.png）の作り直し

リンクを SNS に貼った時のカード画像（1200×630）。場面は Godot でゲームのモデル・空・光をそのまま描き、題字は HTML で重ねる。

```
GODOT=<Godot 4.7 の console 版の実行ファイル> bun render.ts   # 場面を build/render.png に描く（小さな窓が一瞬出る）
bun compose.ts                                                # 題字を重ねて ../docs/ogp.png に書く
```

- `scene/` は場面用のファイル（`ogp.tscn`、`ogp_scene.gd`、`ogp_scene.json`）。`render.ts` がゲーム本体（`../game/`）を `build/game/` へ写し、ここに足して描く。配置・カメラ・空の色は `ogp_scene.json` で変える
- `compose.html` が題字・キャッチコピー・星の飾り。フォントはゲームに同梱の M PLUS Rounded 1c（`../game/fonts/`）
- `compose.ts` は PC に入っている Microsoft Edge の画面なしの撮影を使う（Windows の Edge 157 で確かめた）。場所は環境変数 `EDGE_PATH` でも指定できる
- `build/` は作業用（Godot のキャッシュは PC の絶対パスを含む）。Git に入れない
- カードの文面（タイトル・説明・画像の URL）は、作品の直下の `web-head.html`。Godot で Web 書き出しをする時に、書き出し設定の「HTML > Head Include」（`export_presets.cfg` の `html/head_include`）へこの中身を入れると、`docs/index.html` の head に入る
