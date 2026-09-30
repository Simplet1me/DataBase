import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { writeFileSync } from "node:fs";
import path from "node:path";
import { root, resetDemo, sql } from "../scripts/db.mjs";

// 按测试文档第4节顺序执行完整演示，所有账号和初始数据与55例共用。
const base = "http://localhost:18081/api",
  tokens = {},
  steps = [];
async function req(user, method, url, data, code = 0) {
  const r = await fetch(base + url, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(tokens[user] ? { Authorization: `Bearer ${tokens[user]}` } : {}),
    },
    ...(data === undefined ? {} : { body: JSON.stringify(data) }),
  });
  const body = await r.json();
  assert.equal(body.code, code, JSON.stringify(body));
  return body.data;
}
const post = (u, p, d, c = 0) => req(u, "POST", p, d, c);
const audit = (u, p, result = "agree") => post(u, p, { result });
const record = (number, text) => {
  steps.push({ number, text, status: "通过" });
  console.log(`演示 ${number}: ${text}`);
};
resetDemo();
try {
  for (const account of [
    "2021001",
    "2021006",
    "2021007",
    "2021008",
    "2021010",
    "T001",
    "T003",
  ]) {
    const login = await post("", "/auth/login", {
      userType: account.startsWith("T") ? "teacher" : "student",
      account,
      password: createHash("sha256").update("123456").digest("hex"),
    });
    tokens[account] = login.token;
  }
  const initial = await req("T003", "GET", "/teacher/club");
  assert.equal(initial.members.length, 3);
  record(1, "教师登录并查看篮球社全量数据");
  const join = await post("2021010", "/clubs/1/join-applies");
  await post("2021010", "/clubs/1/join-applies", undefined, 1001);
  record(2, "学生浏览并申请入社，重复申请被拒");
  await audit("2021006", `/join-applies/${join.applyId}/audit`);
  assert.equal(
    (await req("2021010", "GET", "/auth/profile")).club.clubRole,
    "member",
  );
  record(3, "社长同意，触发器自动录入社员");
  const message = await post("2021006", "/messages", {
    msgTitle: "社团文化节即将开始",
    msgContent: "欢迎各社团报名参加校园文化节。",
  });
  record(4, "复合身份账号以学生会权限发布消息");
  await post("2021008", "/clubs/1/role-change", {
    stuId: "2021009",
    newRole: "vice_president",
  });
  await post(
    "2021008",
    "/clubs/1/role-change",
    { stuId: "2021010", newRole: "vice_president" },
    1001,
  );
  await post("2021008", "/clubs/1/members/2021010/kick");
  record(5, "副社长晋升、第三副社长拦截及踢出留痕");
  await post("2021006", "/clubs/1/change-president", {
    demoteStuIds: ["2021006"],
    newPresidentStuId: "2021008",
  });
  record(6, "原社长原子换届为2021008，角色日志保存");
  const body = {
    clubName: "摄影社",
    clubDesc: "记录校园里的光影与故事",
    applyTeaId: "T001",
    stuIds: ["2021001", "2021002", "2021003", "2021004", "2021005"],
  };
  const create = await post("2021001", "/create-applies", body);
  // 同一组学生尚未入社时预先提交待驳回申请，避免凭空增加文档蓝图之外的账号。
  const reject = await post("2021001", "/create-applies", {
    ...body,
    clubName: "校园影像社",
    applyTeaId: "T002",
  });
  await audit("2021007", `/union/create-applies/${create.createApplyId}/audit`);
  await audit("T001", `/teacher/create-applies/${create.createApplyId}/audit`);
  const club = (await req("2021001", "GET", "/auth/profile")).club;
  assert.equal(club.clubRole, "president");
  record(7, "五人建团通过学生会与教师审批，生成1正2副2社员");
  await audit(
    "2021007",
    `/union/create-applies/${reject.createApplyId}/audit`,
    "reject",
  );
  record(8, "第二份预提交申请被学生会驳回，未创建社团");
  const activity = await post("2021001", `/clubs/${club.clubId}/activities`, {
    actName: "校园摄影行",
    actDesc: "用镜头发现校园",
    actStartTime: "2026-10-05 09:00:00",
    actEndTime: "2026-10-05 12:00:00",
    actPlace: "校园广场",
  });
  await audit("T001", `/teacher/activities/${activity.actId}/audit`);
  await post(
    "2021001",
    `/clubs/${club.clubId}/activities/${activity.actId}/finish`,
  );
  record(9, "新社团申办活动，教师通过后由管理层完结");
  await post("2021001", `/clubs/${club.clubId}/notices`, {
    noticeTitle: "首次摄影活动结束",
    noticeContent: "感谢大家的参与。",
  });
  const dissolve = await post(
    "2021001",
    `/clubs/${club.clubId}/dissolve-applies`,
  );
  await post("2021010", `/clubs/${club.clubId}/join-applies`, undefined, 1001);
  await audit(
    "2021007",
    `/union/dissolve-applies/${dissolve.dissolveApplyId}/audit`,
  );
  await audit(
    "T001",
    `/teacher/dissolve-applies/${dissolve.dissolveApplyId}/audit`,
  );
  assert.equal(
    Number(
      sql(
        `USE club_manage_test; SELECT COUNT(*) FROM club WHERE club_id=${club.clubId}`,
      ),
    ),
    0,
  );
  record(10, "冻结期间入社被拒，双审解散删除数据并释放身份");
  await post("2021007", "/union/members", { stuId: "2021010" });
  await req("2021007", "DELETE", "/union/members/2021010");
  await req("2021007", "DELETE", "/union/members/2021006");
  await req("2021007", "DELETE", "/union/members/2021007", undefined, 1001);
  record(11, "学生会新增移除留痕，最后一人保护生效");
  for (const user of ["2021001", "2021008", "2021007", "T003"])
    assert.ok(
      (await req(user, "GET", "/messages")).some(
        (m) => m.msgId === message.msgId,
      ),
    );
  await req("2021007", "DELETE", `/messages/${message.msgId}`);
  assert.ok(
    !(await req("T003", "GET", "/messages")).some(
      (m) => m.msgId === message.msgId,
    ),
  );
  record(12, "四类角色均可查看消息，软删除后不可见");
  writeFileSync(
    path.join(root, "test/demo-results.md"),
    [
      "# 端到端演示执行记录",
      `\n执行时间：${new Date().toISOString()}`,
      "\n|步骤|实际执行|结果|",
      "|---|---|---|",
      ...steps.map((s) => `|${s.number}|${s.text}|${s.status}|`),
      "\n说明：文档只提供一组空闲的五人建团账号。第二份待驳回申请在第一份成功前预先提交，随后按第8步驳回；未增加蓝图外账号。测试完成后恢复通用演示数据。",
    ].join("\n"),
  );
} finally {
  resetDemo();
}
