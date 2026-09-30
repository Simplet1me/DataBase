# 青禾校园 · 高校学生社团管理系统

项目已补全后端与15个前端页面，附可运行JAR、前端构建产物、演示数据和测试记录。原始开发提示词保留在本文后部。

## 快速运行（Windows交付包）

1. 确保Java17+、Node22.12+和MySQL已安装且服务运行。默认MySQL账号root、密码123456；可用DB_USER/DB_PASSWORD环境变量覆盖。
2. 首次双击 `scripts/init-db.bat` 创建项目库（已有表时停止，不覆盖数据）。MySQL客户端不在默认位置时，设置MYSQL_BIN为mysql.exe完整路径。
3. 双击 `scripts/import-demo.bat` 导入预置账号与篮球社。该步骤会清空club_manage中的现有业务数据，只用于首次演示或显式重置。
4. 双击 `scripts/start-all.bat`，打开 **http://localhost:5173**。启动不安装依赖、不重置数据库，前后端进程隐藏运行，日志在logs目录。
5. 双击 `scripts/stop-all.bat` 停止本脚本启动的进程。

|身份|账号|密码|
|---|---|---|
|普通学生，入社演示|2021010|123456|
|篮球社社长兼学生会|2021006|123456|
|篮球社副社长|2021008|123456|
|学生会审批人|2021007|123456|
|篮球社指导教师|T003|123456|
|空闲教师、建团审批|T001、T002|123456|
|五人建团组|2021001～2021005|123456|

## 开发与验证

- 后端：项目根目录 `mvn spring-boot:run`（或mvnw.cmd），默认8080。
- 前端：frontend目录 `npm ci`、`npm run dev`，默认5173，/api代理到后端。
- 构建：`powershell -ExecutionPolicy Bypass -File scripts/build.ps1`，产物为release/club-manage.jar和frontend/dist。
- 完整复验：安装前端依赖后，`cd frontend`执行`npx playwright install chromium`，回到根目录执行`node scripts/test-all.mjs`。要求Maven可用，仅重置独立club_manage_test；使用18081/15173端口。
- 测试结果：[逐例结果](test/expected-results.md)、[演示剧本](test/demo-results.md)、[测试报告](docs/dev/09-测试报告.md)、[浏览器结果](test/ui-results.json)。

## 必须了解的文档差异

原测试55例中，第50例要求通过未包含审批状态字段的视图更新审批状态，无法在“不修改视图”的约束下原样完成。实际记录为54例通过、1例原要求受限且替代验证通过。换届权限和存储过程内部事务也存在原始约束冲突，已做应用层兼容并说明边界，详见[实现说明](docs/dev/08-实现说明与文档差异.md)。

原始四个SQL设计文件保持不变；初始化脚本处理MySQL8的排序规则继承差异。请优先使用附带脚本初始化，避免直接导入遇到过程参数排序规则冲突。

---

# 原始开发提示词

## 文件清单

设计类（docs/design/）：`需求文档.md`、`sql.sql`、`triggers.sql`、`views.sql`、`procedures.sql`、`ER图.md`
开发类（docs/dev/）：`01-开发文档.md`、`02-接口文档.md`、`03-前端页面方案.md`、`04-一键启动脚本.md`、`05-测试文档.md`、`06-数据库设计说明书.md`、`07-用户手册.md`

---

## 正文

```text
现在要基于我上传的设计文档，实现"高校学生社团管理系统"。

【项目现状】
1. 数据库已全部设计完成：MySQL 库 club_manage，14 张表、3 个触发器、4 个视图、5 个存储过程（见 sql.sql / triggers.sql / views.sql / procedures.sql）。
2. 后端工程已搭好框架：Spring Boot 4.1.1 + Java 17 + Maven，工程根目录即后端，主类 com.simplet1me.database.DataBaseApplication，pom.xml 目前只有 webmvc 和 lombok。
3. 前端工程已搭好框架：frontend/ 目录，Vue 3.5 + vue-router 5.3 + Element Plus 2.14 + Vite 8.3（未装 axios/pinia）。
4. 需求与接口约定以《需求文档.md》《02-接口文档.md》为准，后端实现逻辑以《01-开发文档.md》为准。

【硬性约束（违反即返工）】
1. 数据库结构已定型：禁止新增/删除/修改任何表、字段、索引、触发器、视图、存储过程；业务联动必须严格按数据库对象执行：
   - 入社审批：后端只 UPDATE join_apply（apply_status + approve_stu_id + reply_time），入社记录由触发器 trg_join_apply_audit 自动写入；
   - 建团终审：教师同意且学生会已同意时，调用存储过程 sp_create_club（由它创建社团、录入 5 名发起人、置 final_status）；学生会/教师驳回时后端置 final_status='fail'；
   - 解散终审：教师同意且学生会已同意时，先置 final_status='success' 再调用 sp_dissolve_club（由它事务删除社团数据）；
   - 入社申请提交、角色变更、解散申请提交必须调用对应存储过程（sp_submit_join_apply / sp_change_member_role / sp_submit_dissolve_apply）；
   - 换届走专用接口：后端在同一个 @Transactional 内先对降级名单逐个调 sp_change_member_role 置 member，再调 sp_change_member_role 置新社长 president，任一步失败整体回滚。
2. 存储过程 SIGNAL 的业务错误信息必须原样透传给前端（错误码 1001）；唯一键冲突（DuplicateKeyException）返回 1002。
3. 接口必须与《02-接口文档.md》完全一致：路径、请求/响应字段、权限要求、错误码不得自行增删改；统一响应 { code, message, data }；时间格式 yyyy-MM-dd HH:mm:ss。
4. 权限按《01-开发文档.md》§5.2 矩阵实现：JWT（auth0 java-jwt），拦截器只校验登录态，权限校验一律在 Service 层；复合身份（学生会成员/社团角色）每次请求实时计算。
5. 数据访问层用 MyBatis（mybatis-spring-boot-starter 4.x，兼容 Spring Boot 4；存储过程用 statementType="CALLABLE" 调用）；若你判断 MyBatis 4.x 与 Boot 4.1.1 存在兼容问题，改用 spring-boot-starter-jdbc + JdbcTemplate 并在说明中注明原因。
6. 密码存储为 SHA-256 哈希（应用层比对，不存明文）；全部代码用中文注释；SQL 全参数化。
7. 审批类接口的 UPDATE 一律带原状态条件（如 WHERE apply_status='pending'），影响行数为 0 时返回 404"该申请已被处理"。
8. 需求文档中的 12 条约束必须逐条在后端落实（约束→数据库对象映射见《06-数据库设计说明书.md》§5.3），不得遗漏任何校验。

【工作方式】
严格按《01-开发文档.md》§8 的里程碑 M1→M7 顺序开发，一次只完成一个里程碑：
- 每个里程碑结束时：给出该阶段全部文件的完整代码（每个文件标注完整路径）、改动清单、与接口文档的对应关系、手工自测步骤；
- 然后停下，等我回复"继续"再进入下一里程碑；
- 后端 M1~M7 全部完成并经我确认后，我会说"开始前端"，届时再按《03-前端页面方案.md》生成 Vue3 前端页面（先补装 axios/pinia 与 Vite 代理，再按 15 页清单逐个实现，页面必须调用 02 文档定义的接口）。

【输出规范】
1. 每个文件用"文件路径"标题 + 代码块输出完整内容，不要省略、不要用"其余同上"；
2. 代码可直接编译/运行（注意 Spring Boot 4 的 starter 命名、@RestController 等写法）;
3. 禁止行为：不修改数据库设计、不自创接口或字段、不简化校验逻辑、不跳过异常处理、不用英文注释。

【环境信息】
- 后端端口 8080，包名 com.simplet1me.database；
- 数据库连接配置键按《01-开发文档.md》§3.2 账号为root，密码123456；
- 前端端口 5173，/api 经 Vite 代理到 8080。

全部完成后按 [05-测试文档.md](05-测试文档.md) 执行 55 个用例与演示剧本

- 报错修复时：`请按上面的约束修复以下报错，只输出修改涉及的文件，不要改动其他部分：<粘贴报错>`
- 前端阶段：`开始前端。按《03-前端页面方案.md》实现，先补 axios/pinia 与 Vite 代理配置，再按 F1→F6 顺序逐页实现，页面严格调用《02-接口文档.md》的接口与字段。`
- 测试数据：`按《05-测试文档.md》第 2 节蓝图生成 test/demo-data.sql（幂等、可重复执行、中文注释说明每个账号用途），并生成 test/expected-results.md 模板。`
```
