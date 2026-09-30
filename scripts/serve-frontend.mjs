import http from 'node:http'
import { createReadStream, existsSync, statSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

// 交付版仅用 Node 内置模块托管构建产物，并代理同源接口，不需要安装前端依赖。
const dist = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../frontend/dist')
const port = Number(process.env.FRONTEND_PORT || 5173)
const backend = new URL(process.env.API_TARGET || 'http://127.0.0.1:8080')
if (!existsSync(path.join(dist, 'index.html'))) throw new Error('缺少 frontend/dist，请先运行构建脚本')
const mime = { '.html':'text/html; charset=utf-8', '.js':'text/javascript; charset=utf-8', '.css':'text/css; charset=utf-8', '.svg':'image/svg+xml', '.png':'image/png', '.ico':'image/x-icon' }
const server = http.createServer((req, res) => {
  if (req.url.startsWith('/api/')) {
    const upstream = http.request(new URL(req.url, backend), { method:req.method, headers:{ ...req.headers, host:backend.host } }, response => {
      res.writeHead(response.statusCode, response.headers); response.pipe(res)
    })
    upstream.on('error', () => { if (!res.headersSent) res.writeHead(502, { 'Content-Type':'application/json; charset=utf-8' }); res.end(JSON.stringify({ code:500,message:'后端服务暂不可用',data:null })) })
    req.pipe(upstream); return
  }
  if (!['GET','HEAD'].includes(req.method)) { res.writeHead(405); res.end(); return }
  let filename
  try { filename = path.resolve(dist, '.' + decodeURIComponent(new URL(req.url,'http://localhost').pathname)) } catch { res.writeHead(400); res.end(); return }
  if (filename !== dist && !filename.startsWith(dist + path.sep)) { res.writeHead(403); res.end(); return }
  if (filename === dist || (existsSync(filename) && statSync(filename).isDirectory())) filename = path.join(filename,'index.html')
  if (!existsSync(filename) || !statSync(filename).isFile()) { res.writeHead(404); res.end(); return }
  res.writeHead(200, { 'Content-Type':mime[path.extname(filename)] || 'application/octet-stream', 'Cache-Control':filename.endsWith('.html') ? 'no-cache' : 'public,max-age=3600' })
  if (req.method === 'HEAD') res.end(); else createReadStream(filename).pipe(res)
})
server.listen(port,'127.0.0.1',()=>console.log(`青禾校园前端：http://localhost:${port}`))
