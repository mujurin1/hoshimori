// 最小の静的サーバー。使い方: bun serve.ts <フォルダ> [ポート]  (127.0.0.1 のみ)
import { resolve, sep, extname } from "node:path"
import { existsSync, statSync } from "node:fs"

const TYPES: Record<string, string> = {
  ".html": "text/html; charset=utf-8", ".htm": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8", ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8", ".json": "application/json; charset=utf-8",
  ".wasm": "application/wasm", ".pck": "application/octet-stream",
  ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".gif": "image/gif",
  ".svg": "image/svg+xml", ".webp": "image/webp", ".ico": "image/x-icon",
  ".mp3": "audio/mpeg", ".ogg": "audio/ogg", ".wav": "audio/wav",
  ".txt": "text/plain; charset=utf-8", ".woff2": "font/woff2",
}

const root = resolve(process.argv[2] ?? ".")
const port = Number(process.argv[3] ?? 8765)
if (!existsSync(root) || !statSync(root).isDirectory()) {
  console.error(`フォルダが無い: ${root}`)
  process.exit(2)
}

const server = Bun.serve({
  hostname: "127.0.0.1",
  port,
  fetch(req) {
    let path: string
    try { path = decodeURIComponent(new URL(req.url).pathname) } catch { return new Response("bad request", { status: 400 }) }
    if (path.includes("\0")) return new Response("bad request", { status: 400 })
    let file = resolve(root, "." + path)
    if (file !== root && !file.startsWith(root + sep)) return new Response("forbidden", { status: 403 })
    if (existsSync(file) && statSync(file).isDirectory()) file = resolve(file, "index.html")
    if (!existsSync(file) || !statSync(file).isFile()) return new Response("not found", { status: 404 })
    return new Response(Bun.file(file), {
      headers: {
        "Content-Type": TYPES[extname(file).toLowerCase()] ?? "application/octet-stream",
        "Cache-Control": "no-store",
      },
    })
  },
})
console.log(`serving ${root} at http://127.0.0.1:${server.port}/`)
