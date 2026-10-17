@echo off
setlocal
cd /d "%~dp0.."
set "DEMO_SCRIPT=%~f0"
node -e "const fs=require('node:fs');const s=fs.readFileSync(process.env.DEMO_SCRIPT,'utf8').split(/\r?\n\/\/ JAVASCRIPT BELOW\r?\n/)[1];import('data:text/javascript;base64,'+Buffer.from(s).toString('base64')).catch(e=>{console.error(e.message);process.exitCode=1})"
exit /b %errorlevel%
// JAVASCRIPT BELOW
const seedSql = "-- 通用演示数据。仅在本项目演示库执行，会清理该库现有业务数据；可重复执行。\n-- 2021001 张三、2021002 李四、2021003 王五、2021004 赵六、2021005 孙七：五人建团组。\n-- 2021006 周八：篮球社社长兼学生会；2021007 吴九：学生会审批人。\n-- 2021008 郑十：篮球社副社长和换届目标；2021009 冯十一：普通社员退社演示。\n-- 2021010 陈十二：无社团，入社申请演示。T001 刘老师、T002 陈老师空闲；T003 杨老师指导篮球社。\n-- 密码统一为 123456 的 SHA-256，数据库仅保存哈希。\nUSE club_manage;\nSTART TRANSACTION;\nDELETE FROM club_member_change_log;\nDELETE FROM join_apply;\nDELETE FROM club_activity;\nDELETE FROM club_notice;\nDELETE FROM club_dissolve_apply;\nDELETE FROM club_member;\nDELETE FROM club_create_apply_member;\nDELETE FROM club_create_apply;\nDELETE FROM club;\nDELETE FROM system_message;\nDELETE FROM student_union_operate_log;\nDELETE FROM student_union_member;\nDELETE FROM student;\nDELETE FROM teacher;\nINSERT INTO student(stu_id,stu_name,stu_gender,stu_class,stu_phone,stu_pwd) VALUES\n('2021001','张三','男','计算机2101','13800000001',SHA2('123456',256)),\n('2021002','李四','女','计算机2101','13800000002',SHA2('123456',256)),\n('2021003','王五','男','计算机2101','13800000003',SHA2('123456',256)),\n('2021004','赵六','女','计算机2101','13800000004',SHA2('123456',256)),\n('2021005','孙七','男','计算机2101','13800000005',SHA2('123456',256)),\n('2021006','周八','男','软件2102','13800000006',SHA2('123456',256)),\n('2021007','吴九','女','软件2102','13800000007',SHA2('123456',256)),\n('2021008','郑十','男','软件2102','13800000008',SHA2('123456',256)),\n('2021009','冯十一','女','软件2102','13800000009',SHA2('123456',256)),\n('2021010','陈十二','男','软件2102','13800000010',SHA2('123456',256));\nINSERT INTO teacher(tea_id,tea_name,tea_phone,tea_pwd) VALUES\n('T001','刘老师','13900000001',SHA2('123456',256)),\n('T002','陈老师','13900000002',SHA2('123456',256)),\n('T003','杨老师','13900000003',SHA2('123456',256));\nINSERT INTO student_union_member(stu_id) VALUES('2021006'),('2021007');\nINSERT INTO student_union_operate_log(stu_id,operate_type,operate_stu_id) VALUES('2021006','add','2021007'),('2021007','add','2021006');\nINSERT INTO club(club_id,club_name,club_desc,club_create_time,tea_id) VALUES\n(1,'篮球社','在球场相遇，与热爱同行。每周开展训练、友谊赛和校园联赛，欢迎每一位热爱运动的同学。','2026-09-01 09:00:00','T003');\nINSERT INTO club_member(club_id,stu_id,member_role) VALUES(1,'2021006','president'),(1,'2021008','vice_president'),(1,'2021009','member');\nINSERT INTO club_activity(club_id,act_name,act_desc,act_start_time,act_end_time,act_place,act_status,audit_tea_id,audit_time) VALUES\n(1,'秋日篮球友谊赛','一起上场，享受运动。请携带运动装备和饮用水。','2026-10-01 14:00:00','2026-10-01 18:00:00','学校体育馆','running','T003',NOW());\nINSERT INTO club_notice(club_id,notice_title,notice_content,publish_stu_id) VALUES\n(1,'新学期训练安排','每周三与周五 17:00，在东区篮球场集合。欢迎社员参加。','2021006'),\n(1,'社团招新进行中','零基础也欢迎。和我们一起训练，找到属于你的队友。','2021008');\nINSERT INTO system_message(publish_stu_id,msg_title,msg_content) VALUES\n('2021007','新学期，找到你的热爱','社团招新正式开始。前往社团广场探索感兴趣的社团，提交申请后可在个人中心查看进度。'),\n('2021007','校园社团活动申办提醒','活动由本社团管理层发起，经指导教师审批后开展。请提前填写活动时间、地点与内容。');\nCOMMIT;\n";
import { spawnSync } from "node:child_process";
import { readFileSync, existsSync } from "node:fs";
import path from "node:path";

// 所有脚本使用同一个客户端入口，避免命令行明文传密码及中文路径问题。
const root = process.cwd();
const defaultClient = ["C:/Program Files/MySQL/MySQL Server 8.4/bin/mysql.exe", "C:/Program Files/MySQL/MySQL Server 8.0/bin/mysql.exe"].find(existsSync) || "mysql";
const client =
  process.env.MYSQL_BIN ||
  (existsSync(defaultClient) ? defaultClient : "mysql");
function sql(text, database = "club_manage_test") {
  if (!/^club_manage(?:_test)?$/.test(database))
    throw new Error("仅允许操作项目演示库或独立测试库");
  const result = spawnSync(
    client,
    [
      "--default-character-set=utf8mb4",
      "--batch",
      "--raw",
      "--skip-column-names",
      "-h",
      process.env.DB_HOST || "127.0.0.1",
      "-P",
      process.env.DB_PORT || "3306",
      "-u",
      process.env.DB_USER || "root",
    ],
    {
      input: text,
      encoding: "utf8",
      maxBuffer: 20 * 1024 * 1024,
      env: { ...process.env, MYSQL_PWD: process.env.DB_PASSWORD || "123456" },
    },
  );
  if (result.error || result.status !== 0)
    throw new Error(result.error?.message || result.stderr.trim());
  return result.stdout.trim();
}
function initialize(database) {
  const count = Number(
    sql(
      `SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${database}';`,
      database,
    ),
  );
  if (count)
    throw new Error(
      `${database} 已有数据表；初始化已停止，请直接启动。重置演示数据请执行 database_reset.bat。`,
    );
  for (const name of [
    "sql.sql",
    "triggers.sql",
    "views.sql",
    "procedures.sql",
  ]) {
    const content = readFileSync(
      path.join(root, "docs/design", name),
      "utf8",
    ).replaceAll("club_manage", database);
    if (name === "procedures.sql") installProcedures(database, content);
    else sql(content, database);
    console.log(`已初始化 ${database}: ${name}`);
  }
}
// MySQL 8 的显式 utf8mb4 表默认使用 0900 排序规则，过程参数则继承库默认值。
// 在创建原过程时对齐参数的继承环境，再恢复库默认值；原 SQL 文件及对象定义均不改写。
function installProcedures(database, content) {
  const original = sql(
    `SELECT DEFAULT_COLLATION_NAME FROM information_schema.schemata WHERE schema_name='${database}'`,
    database,
  );
  const tableCollation = sql(
    `SELECT TABLE_COLLATION FROM information_schema.tables WHERE table_schema='${database}' AND table_name='student'`,
    database,
  );
  if (
    !/^utf8mb4_[a-z0-9_]+$/.test(tableCollation) ||
    !/^utf8mb4_[a-z0-9_]+$/.test(original)
  )
    throw new Error("数据库排序规则不符合要求");
  try {
    sql(
      `ALTER DATABASE ${database} COLLATE ${tableCollation};\n${content}`,
      database,
    );
  } finally {
    sql(`ALTER DATABASE ${database} COLLATE ${original};`, database);
  }
}
function resetDemo(database = "club_manage_test") {
  sql(
    seedSql.replaceAll(
      "club_manage",
      database,
    ),
    database,
  );
}

const { createInterface } = await import('node:readline/promises');
const rl = createInterface({ input: process.stdin, output: process.stdout });
let answer;
try { answer = await rl.question('将删除 club_manage 并恢复演示数据。请输入 RESET 确认：'); } finally { rl.close(); }
if (answer !== 'RESET') { console.log('已取消。'); } else {
  sql('DROP DATABASE IF EXISTS club_manage;', 'club_manage');
  initialize('club_manage'); resetDemo('club_manage');
  console.log('数据库已重置。');
}
