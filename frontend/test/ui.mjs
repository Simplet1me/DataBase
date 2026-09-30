import { chromium } from '@playwright/test'
import assert from 'node:assert/strict'
import { existsSync, mkdirSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import { root, resetDemo } from '../../scripts/db.mjs'

// 使用真实浏览器与真实测试服务，不拦截或伪造接口响应。
const base = process.env.UI_URL || 'http://127.0.0.1:15173'
const supplied = process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE
const local = 'C:/Users/zzz/AppData/Local/ms-playwright/chromium-1217/chrome-win64/chrome.exe'
const browser = await chromium.launch({ headless: true, ...(supplied || existsSync(local) ? { executablePath: supplied || local } : {}) })
const context = await browser.newContext({ viewport: { width: 1440, height: 1000 }, locale: 'zh-CN' })
const page = await context.newPage(), errors = [], checked = []
const output = path.join(root, 'test/screenshots')
mkdirSync(output, { recursive: true })
page.on('pageerror', e => errors.push(e.message))
page.on('response', async response => { if (response.url().includes('/api/')) { try { const r = await response.json(); if (r.code === 500) errors.push(`${response.url()}: ${r.message}`) } catch {} } })
async function navigate(route) { await page.goto(`${base}/?ui=${Date.now()}#${route}`); await page.waitForLoadState('networkidle'); await page.locator('.el-loading-mask:visible').waitFor({ state: 'hidden', timeout: 15000 }).catch(() => {}); assert.ok(await page.locator('body').innerText()); checked.push(route) }
async function login(account, type = 'student') {
  await page.goto(`${base}/#/login`)
  if (type === 'teacher') await page.locator('.el-radio-button').filter({ hasText: '教师' }).click()
  await page.getByPlaceholder('请输入学号 / 工号').fill(account)
  await page.getByPlaceholder('请输入登录密码').fill('123456')
  await page.getByRole('button', { name: '登录青禾' }).click()
  await page.waitForURL(url => url.hash === (type === 'teacher' ? '#/teacher/workbench' : '#/clubs'))
  await page.waitForLoadState('networkidle')
  checked.push(type === 'teacher' ? '/teacher/workbench' : '/clubs')
}
try {
  resetDemo()
  await navigate('/login')
  await page.screenshot({ path: path.join(output, '01-login.png'), fullPage: true })
  await login('2021010')
  await page.screenshot({ path: path.join(output, '02-clubs.png'), fullPage: true })
  await page.getByRole('button', { name: '了解社团' }).click()
  await page.getByRole('heading', { name: '社团公告' }).waitFor()
  await page.keyboard.press('Escape')
  await page.getByRole('button', { name: '申请加入', exact: true }).click()
  await page.getByText('申请已提交，请在个人中心查看审批进度').waitFor()
  await navigate('/me')
  await page.getByRole('tab', { name: '入社申请', exact: true }).click()
  await page.locator('.el-tab-pane:visible').getByText('待审批').waitFor()
  await navigate('/club/create')
  await navigate('/messages')
  await login('2021006')
  for (const route of ['/manage/overview','/manage/members','/manage/audit','/manage/activities','/manage/notices','/manage/dissolve','/union/audit','/union/members','/union/messages']) await navigate(route)
  await navigate('/manage/audit')
  await page.getByRole('button', { name: '同意', exact: true }).click()
  await page.getByRole('button', { name: '确认', exact: true }).click()
  await page.getByText('暂时没有待审批的入社申请').waitFor()
  await navigate('/manage/overview')
  await page.screenshot({ path: path.join(output, '03-manager.png'), fullPage: true })
  await navigate('/union/messages')
  await page.getByRole('button', { name: '发布消息' }).click()
  await page.getByLabel('消息标题').fill('浏览器测试公告')
  await page.getByLabel('消息内容').fill('通过真实表单发布的校园公告。')
  await page.getByRole('button', { name: '保存', exact: true }).click()
  const card = page.locator('article').filter({ has: page.getByRole('heading', { name: '浏览器测试公告', exact: true }) })
  await card.waitFor()
  await card.getByRole('button', { name: '编辑', exact: true }).click()
  await page.getByLabel('消息标题').fill('浏览器测试公告已编辑')
  await page.getByRole('button', { name: '保存', exact: true }).click()
  const edited = page.locator('article').filter({ has: page.getByRole('heading', { name: '浏览器测试公告已编辑', exact: true }) })
  await edited.getByRole('button', { name: '删除', exact: true }).click()
  await page.getByRole('button', { name: '确认', exact: true }).click()
  await edited.waitFor({ state: 'detached' })
  await login('2021010')
  await navigate('/me')
  await page.getByRole('button', { name: '退出社团', exact: true }).click()
  await page.getByRole('button', { name: '确认', exact: true }).click()
  await page.getByText('尚未加入社团，去发现感兴趣的伙伴吧。').waitFor()
  await login('T003','teacher')
  await page.getByRole('tab', { name: '所辖社团' }).click()
  await page.getByRole('heading', { name: '篮球社', exact: true }).waitFor()
  await page.screenshot({ path: path.join(output, '04-teacher.png'), fullPage: true })
  await navigate('/manage/members')
  await page.waitForURL(url => url.hash === '#/clubs')
  assert.match(page.url(), /#\/clubs$/)
  await page.setViewportSize({ width: 390, height: 844 })
  await navigate('/clubs')
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false, '移动端不应横向溢出')
  await page.getByRole('button', { name: '展开菜单' }).click()
  await page.locator('.sidebar.is-open').waitFor()
  await page.getByRole('button', { name: '关闭菜单' }).click()
  await page.screenshot({ path: path.join(output, '05-mobile.png'), fullPage: true })
  assert.deepEqual(errors, [], '页面不应出现脚本异常或服务器错误')
  writeFileSync(path.join(root,'test/ui-results.json'), JSON.stringify({ date:new Date().toISOString(), status:'通过', routes:[...new Set(checked)], checks:['15页覆盖','学生表单登录','教师表单登录','社团详情','入社申请与审批','主动退社通过档案视图更新','系统消息新增编辑删除','越权路由重定向','390px响应式导航','无页面脚本异常与500'], errors },null,2))
  console.log(`浏览器验证通过，访问 ${new Set(checked).size} 个页面路径；截图 ${output}`)
} catch(error) {
  await page.screenshot({ path:path.join(output,'failure.png'), fullPage:true })
  writeFileSync(path.join(root,'test/ui-results.json'),JSON.stringify({status:'失败',error:error.message,errors,checked},null,2))
  throw error
} finally { await browser.close(); resetDemo() }
