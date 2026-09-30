import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs'
import { createHash } from 'node:crypto'
import path from 'node:path'
import { root } from './db.mjs'

// 修正原开发文档的相对链接，不改数据库设计文档和SQL。
for(const file of readdirSync(path.join(root,'docs/dev')).filter(f=>f.endsWith('.md'))) {
  const location=path.join(root,'docs/dev',file)
  let text=readFileSync(location,'utf8')
  for(const name of ['需求文档.md','sql.sql','triggers.sql','views.sql','procedures.sql','ER图.md']) text=text.replaceAll(`](../${name})`,`](../design/${name})`)
  writeFileSync(location,text)
}
const execution=JSON.parse(readFileSync(path.join(root,'test/results.json'),'utf8'))
// 预期列只来自55例章节，避免与演示步骤的相同编号混淆。
const testDocument=readFileSync(path.join(root,'docs/dev/05-测试文档.md'),'utf8').split('## 4 端到端演示剧本')[0]
const expected=new Map([...testDocument.matchAll(/^\|\s*(\d+)\s*\|\s*([^|]+)\|\s*([^|]+)\|\s*([^|]+)\|/gm)].map(m=>[Number(m[1]),m[4].trim()]))
const resultPath=path.join(root,'test/expected-results.md')
const fixed=readFileSync(resultPath,'utf8').split('\n').map(line=>{
  const match=line.match(/^\|(\d+)\|/)
  if(!match||!expected.has(Number(match[1])))return line
  const columns=line.split('|');columns[3]=expected.get(Number(match[1]));return columns.join('|')
}).join('\n')
writeFileSync(resultPath,fixed)
const controller=readFileSync(path.join(root,'src/main/java/com/simplet1me/database/controller/ApiController.java'),'utf8')
const mappings=[...controller.matchAll(/@(Get|Post|Put|Delete)Mapping\("([^"]+)"\)/g)].map(m=>({method:m[1].toUpperCase(),route:m[2]}))
const rows=mappings.map(m=>{
  const pattern=new RegExp('^'+m.route.replace(/\{[^}]+\}/g,'[^/]+')+'$')
  const traces=execution.traces.filter(t=>t.method===m.method&&pattern.test(t.route))
  return {...m,codes:[...new Set(traces.map(t=>t.code))].sort((a,b)=>a-b),covered:traces.length>0}
})
writeFileSync(path.join(root,'test/api-coverage.md'),['# 接口覆盖清单',`\n从ApiController自动提取${rows.length}个方法与路径组合，HTTP实测覆盖${rows.filter(r=>r.covered).length}个。响应码为实际测试轨迹出现的值，不代表每条接口都遍历所有错误码。`,'\n|方法|路径|覆盖|实际响应码|','|---|---|---|---|',...rows.map(r=>`|${r.method}|/api${r.route}|${r.covered?'已执行':'未覆盖'}|${r.codes.join('、')}|`)].join('\n'))
if(rows.some(r=>!r.covered)) console.warn('尚未覆盖：',rows.filter(r=>!r.covered))
const ignored=new Set(['node_modules','target','.git','logs'])
function walk(directory) {
  return readdirSync(directory,{withFileTypes:true}).flatMap(entry=>{
    if(ignored.has(entry.name)||['source-manifest.md','failure.png'].includes(entry.name))return[]
    const file=path.join(directory,entry.name)
    return entry.isDirectory()?walk(file):[file]
  })
}
const files=walk(root).sort()
writeFileSync(path.join(root,'test/source-manifest.md'),['# 交付文件清单',`\n根目录：${root}。列出完整相对路径、字节数及SHA-256；不含本清单自身、依赖缓存、临时日志、target。`, '\n|文件|字节|SHA-256|','|---|---|---|',...files.map(file=>`|${path.relative(root,file).replaceAll('\\','/')}|${statSync(file).size}|${createHash('sha256').update(readFileSync(file)).digest('hex')}|`)].join('\n'))
console.log(`接口覆盖${rows.filter(r=>r.covered).length}/${rows.length}，交付清单${files.length}个文件。`)
