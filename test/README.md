# test 目录说明

- expected-results.md / results.json：55个原用例与9个补充边界用例的实测记录。54个原例通过；第50例原要求受限，替代验证通过。
- demo-flow.mjs / demo-results.md：12步骤端到端演示与实际结果。
- ui-results.json / screenshots：15页真实浏览器检查、移动布局及界面截图；测试源码在frontend/test/ui.mjs。
- java-test-results.txt：4项Java/MockMvc测试结果。
- api-coverage.md：52个控制器方法与路径组合的实际调用覆盖。
- database-integrity.md：四个原SQL哈希比对及数据库对象数量。
- release-smoke.md：交付JAR与静态前端启动/代理/登录/停止检查。
- source-manifest.md：交付文件、大小及SHA-256。

原始约定保留如下。

本目录存放项目的测试与演示数据（方案见 [docs/dev/05-测试文档.md](../docs/dev/05-测试文档.md)）。

## 约定

| 文件 | 内容 | 说明 |
| --- | --- | --- |
| demo-data.sql | 通用演示数据 | 项目完成后生成；幂等（先按外键依赖逆序清理再插入），文件头注释每个账号/数据的演示用途 |
| expected-results.md | 测试用例结果记录 | 按 05 文档第 3 节用例清单逐条记录：预期结果 / 实际结果 / 通过状态 |

## 原则

- 一套通用数据覆盖四类角色（学生/管理层/学生会/教师）与全部演示剧本，测试、答辩、验收三处同源；
- 演示数据执行前必须先完成数据库初始化（docs 下四个 SQL：sql.sql → triggers.sql → views.sql → procedures.sql）。
