// OGP 画像の場面を Godot で描いて build/render.png に保存する。
// 使い方: GODOT=<Godot 4.7 の console 版の実行ファイル> bun render.ts
// ゲーム本体（../game）を build/game へ写し、scene/ の場面ファイルを足して描く。場面ファイルを game/ に置くと Web 書き出しに混ざる
import { cpSync, existsSync, mkdirSync, readdirSync, rmSync, statSync } from "node:fs"
import { join } from "node:path"

const here = import.meta.dir
const godot = process.env.GODOT ?? Bun.which("godot")
if (!godot || !existsSync(godot)) { console.error("Godot が見つからない。環境変数 GODOT に Godot 4.7 の console 版の実行ファイルのパスを設定する"); process.exit(2) }

const build = join(here, "build")
const project = join(build, "game")
mkdirSync(project, { recursive: true })
// .godot（取り込みのキャッシュ）だけ残して写し直す。audio は場面に要らない（Sfx はファイルが無くても動く）
for (const n of readdirSync(project)) if (n !== ".godot") rmSync(join(project, n), { recursive: true })
for (const n of readdirSync(join(here, "..", "game"))) {
  if (n === ".godot" || n === "audio") continue
  cpSync(join(here, "..", "game", n), join(project, n), { recursive: true })
}
for (const n of readdirSync(join(here, "scene"))) cpSync(join(here, "scene", n), join(project, n))

function run(args: string[], timeoutMs: number): { code: number; out: string } {
  const p = Bun.spawnSync([godot!, "--path", project, ...args], { stdout: "pipe", stderr: "pipe", timeout: timeoutMs })
  return { code: p.exitCode ?? -1, out: p.stdout.toString() + p.stderr.toString() }
}

if (!existsSync(join(project, ".godot"))) run(["--headless", "--import"], 120000)
// 窓を出す前に画面なしで回してスクリプトのエラーを見る。壊れたまま窓を出すと真っ黒のまま終わらない
const check = run(["--headless", "--quit-after", "10", "--fixed-fps", "60", "res://ogp.tscn"], 60000)
const errs = check.out.split("\n").filter((l) => /SCRIPT ERROR|Parse Error|ERROR:/.test(l))
if (errs.length) { console.error(errs.join("\n")); process.exit(1) }

const out = join(build, "render.png")
const before = existsSync(out) ? statSync(out).mtimeMs : 0
// 撮影のフレームを固定するため --fixed-fps を付ける。場面は撮り終えると自分で終わる
const r = run(["--windowed", "--resolution", "600x315", "--audio-driver", "Dummy", "--fixed-fps", "60", "res://ogp.tscn", "--", `--out=${out}`], 60000)
const bad = r.out.split("\n").filter((l) => /ERROR/.test(l))
if (bad.length) console.error(bad.join("\n"))
if (!existsSync(out) || statSync(out).mtimeMs <= before) { console.error("render.png が出来ていない\n" + r.out); process.exit(1) }
console.log("ok build/render.png", statSync(out).size, "bytes")
