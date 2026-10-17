# 高校学生社团管理系统

后端：Java 17、Spring Boot、MyBatis、MySQL。前端：Vue 3、Element Plus、Pinia、Vite。

## 快速运行

1. 启动 MySQL，在 `frontend` 目录执行 `npm ci`。
2. 执行 `demo\database_init.bat`，初始化数据库和测试账号；已有表时停止。
3. 执行 `demo\build.bat`，仅编译后端，生成 `release\club-manage.jar`。
4. 执行 `demo\start.bat`，访问 http://localhost:5173 。前后端在同一终端运行，按 Ctrl+C 或关闭终端一起停止。

恢复演示数据：停止服务，运行 `demo\database_reset.bat` 并输入 `RESET`，将清空重建 `club_manage`。

账号、环境配置和测试步骤见 [测试手册](demo/测试手册.md)。

## 目录

- `src/`：后端代码、MyBatis SQL 和配置。
- `frontend/`：前端页面及组件。
- `docs/design/`：需求、ER 图和原始数据库设计。
- `docs/dev/`：接口、实现说明等开发文档。
- `demo/`：测试手册、初始化、重置、后端编译和启动脚本。
- `release/`：编译生成的后端 JAR。

数据库结构保持原设计，业务联动使用既有触发器和存储过程；权限由 Service 层实时校验。实现边界见 [实现说明](docs/dev/08-实现说明与文档差异.md)。
