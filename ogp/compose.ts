// compose.html（build/render.png の場面 + 題字）を Edge の画面なしで 1200x630 に撮り、../docs/ogp.png にする。
// 使い方: bun compose.ts [出力先]   （先に bun render.ts。Edge の場所は環境変数 EDGE_PATH でも指定できる）
import { existsSync, mkdirSync, statSync } from "node:fs"
import { join, resolve } from "node:path"
import { pathToFileURL } from "node:url"

const here = import.meta.dir
const out = resolve(process.argv[2] ?? join(here, "..", "docs", "ogp.png"))
if (!existsSync(join(here, "build", "render.png"))) { console.error("build/render.png が無い。先に bun render.ts"); process.exit(2) }

const pf = [process.env["ProgramFiles(x86)"], process.env.ProgramFiles].filter(Boolean) as string[]
const edge = process.env.EDGE_PATH ?? pf.map((d) => join(d, "Microsoft", "Edge", "Application", "msedge.exe")).find(existsSync)
if (!edge || !existsSync(edge)) { console.error("Edge が見つからない。環境変数 EDGE_PATH で指定する"); process.exit(2) }

// 普段使いの Edge と設定を共有しないよう、専用のプロファイルを使う。virtual-time-budget の間にフォントと画像の読み込みを待つ
const profile = join(here, "build", "edge-profile")
mkdirSync(profile, { recursive: true })
const before = existsSync(out) ? statSync(out).mtimeMs : 0
const p = Bun.spawnSync([
  edge, "--headless", "--hide-scrollbars", "--force-device-scale-factor=1", "--window-size=1200,630",
  "--virtual-time-budget=5000", `--user-data-dir=${profile}`, `--screenshot=${out}`,
  pathToFileURL(join(here, "compose.html")).href,
], { stdout: "pipe", stderr: "pipe", timeout: 60000 })
if (!existsSync(out) || statSync(out).mtimeMs <= before) {
  console.error("撮影に失敗した\n" + p.stdout.toString() + p.stderr.toString())
  process.exit(1)
}
console.log("ok", out, statSync(out).size, "bytes")
