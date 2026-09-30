# 交付启动验证

已使用Windows PowerShell 5的一键脚本启动release/club-manage.jar及Node静态前端。

- 前端5173：HTTP 200。
- /api代理未登录请求：统一响应code=401。
- 学生2021006登录：code=0，篮球社社长身份正确。
- stop-all.ps1停止成功，8080与5173端口释放。
- 演示库已初始化并保留原始演示数据；再次双击start-all.bat即可启动。
