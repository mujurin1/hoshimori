#!/usr/bin/env bun

// デスクトップ版を起動する。Godot 4.7 が要る
// 探す順: 環境変数 GODOT → このフォルダの 2 つ上の tools/godot（作った環境での置き場所）→ PATH の godot

import { existsSync, readdirSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))

function findGodot(): string | null {
  if (process.env.GODOT) return process.env.GODOT
  const dir = join(here, '..', '..', 'tools', 'godot')
  if (existsSync(dir)) {
    const exe = readdirSync(dir).find((n) => /^Godot_v.*_win64\.exe$/.test(n))
    if (exe) return join(dir, exe)
  }
  return Bun.which('godot')
}

const godot = findGodot()
if (!godot) {
  console.error('Godot が見つからない。Godot 4.7 を入れて、環境変数 GODOT に実行ファイルのパスを設定する')
  process.exit(1)
}
// cmd の start で切り離して起動する。Bun.spawn の子は、bun が終わると道連れで終了する（窓が出ない）
// 入出力は必ず ignore にする。パイプを渡すと Godot がそれを握り、Godot が終わるまでこのスクリプトが戻らない
const r = Bun.spawnSync(['cmd', '/c', 'start', '', godot, '--path', join(here, 'game'), ...process.argv.slice(2)], {
  stdin: 'ignore',
  stdout: 'ignore',
  stderr: 'ignore',
})
process.exit(r.exitCode ?? 1)
