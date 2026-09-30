# 高校学生社团管理系统前端

Vue3 + Vue Router + Pinia + Axios + Element Plus + Vite，包含15个页面。依赖精确版本以package-lock.json为准。

```powershell
npm ci
npm run dev
npm run build
```

默认5173端口，/api代理到http://localhost:8080；可用API_TARGET覆盖代理。交付的dist也可由项目根目录scripts/serve-frontend.mjs托管，不需要安装前端依赖。

路由使用hash模式，静态托管可直接刷新任何页面。后端JWT登录态保存到本地，导航与窗口重新获得焦点时刷新复合身份；所有授权仍由后端Service实时判定。

浏览器复验：项目根目录运行node scripts/test-all.mjs。测试代码在test/ui.mjs，要求已安装Playwright Chromium；支持PLAYWRIGHT_CHROMIUM_EXECUTABLE指定已有浏览器可执行文件。截图和结果写入项目根目录test。
