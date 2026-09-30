import { spawnSync } from "node:child_process";
import { readFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

// 所有脚本使用同一个客户端入口，避免命令行明文传密码及中文路径问题。
export const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const defaultClient = "C:/Program Files/MySQL/MySQL Server 8.0/bin/mysql.exe";
const client =
  process.env.MYSQL_BIN ||
  (existsSync(defaultClient) ? defaultClient : "mysql");
export function sql(text, database = "club_manage_test") {
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
export function initialize(database) {
  const count = Number(
    sql(
      `SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${database}';`,
      database,
    ),
  );
  if (count)
    throw new Error(
      `${database} 已有数据表；初始化已停止，请直接启动。重置演示数据请单独执行 demo 命令。`,
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
export function installProcedures(database, content) {
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
export function resetDemo(database = "club_manage_test") {
  sql(
    readFileSync(path.join(root, "test/demo-data.sql"), "utf8").replaceAll(
      "club_manage",
      database,
    ),
    database,
  );
}
if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  const action = process.argv[2] || "init";
  const database = process.argv[3] || "club_manage";
  if (!/^club_manage(?:_test)?$/.test(database))
    throw new Error("数据库名称不允许");
  if (action === "init") initialize(database);
  else if (action === "demo") {
    resetDemo(database);
    console.log(`演示数据已导入 ${database}`);
  } else
    throw new Error(
      "用法：node scripts/db.mjs init|demo [club_manage|club_manage_test]",
    );
}
