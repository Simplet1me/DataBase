import { spawn } from "node:child_process";
import { createWriteStream } from "node:fs";
import { existsSync, mkdirSync } from "node:fs";
import net from "node:net";
import path from "node:path";
import { initialize, resetDemo, root, sql } from "./db.mjs";

// 单一入口依次运行后端用例、完整演示和真实浏览器，不并行改写测试数据。
mkdirSync(path.join(root, "logs"), { recursive: true });
const database = "club_manage_test";
if (
  !Number(
    sql(
      "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='club_manage_test'",
    ),
  )
)
  initialize(database);
resetDemo(database);
function run(command, args, cwd = root) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd,
      stdio: "inherit",
      windowsHide: true,
      shell: process.platform === "win32" && /\.cmd$/.test(command),
    });
    child.once("error", reject);
    child.once("exit", (code) =>
      code === 0 ? resolve() : reject(new Error(`${command} 退出码 ${code}`)),
    );
  });
}
async function free(port) {
  await new Promise((resolve, reject) => {
    const server = net.createServer();
    server.once("error", () =>
      reject(new Error(`测试端口 ${port} 已占用，请先停止测试服务`)),
    );
    server.listen(port, "127.0.0.1", () => server.close(resolve));
  });
}
await free(18081);
await free(15173);
await run(process.platform === "win32" ? "mvn.cmd" : "mvn", ["package"]);
await run(
  process.platform === "win32" ? "npm.cmd" : "npm",
  ["run", "build"],
  path.join(root, "frontend"),
);
const env = {
  ...process.env,
  DB_URL:
    "jdbc:mysql://localhost:3306/club_manage_test?useUnicode=true&characterEncoding=UTF-8&serverTimezone=Asia/Shanghai",
  SERVER_PORT: "18081",
  CORS_ORIGINS: "http://127.0.0.1:15173",
  FRONTEND_PORT: "15173",
  API_TARGET: "http://127.0.0.1:18081",
};
const backend = spawn("java", ["-jar", "target/DataBase-0.0.1-SNAPSHOT.jar"], {
  cwd: root,
  env,
  windowsHide: true,
});
const frontend = spawn(process.execPath, ["scripts/serve-frontend.mjs"], {
  cwd: root,
  env,
  windowsHide: true,
});
const backLog = createWriteStream(path.join(root, "logs/test-backend.log"));
backend.stdout.pipe(backLog);
backend.stderr.pipe(backLog);
const frontLog = createWriteStream(path.join(root, "logs/test-frontend.log"));
frontend.stdout.pipe(frontLog);
frontend.stderr.pipe(frontLog);
try {
  let ready = false;
  for (let i = 0; i < 60; i++) {
    try {
      const r = await fetch("http://127.0.0.1:18081/api/clubs");
      if ((await r.json()).code === 401) {
        ready = true;
        break;
      }
    } catch {}
    await new Promise((r) => setTimeout(r, 500));
  }
  if (!ready) throw new Error("测试后端启动失败，请查看 logs/test-backend.log");
  await run(process.execPath, ["test/run-tests.mjs"]);
  await run(process.execPath, ["test/demo-flow.mjs"]);
  await run(process.execPath, ["test/ui.mjs"], path.join(root, "frontend"));
  console.log("全部可执行测试及替代验证完成，报告位于 test 目录。");
} finally {
  backend.kill();
  frontend.kill();
  resetDemo(database);
}
