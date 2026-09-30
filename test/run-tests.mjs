import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { readFileSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import { sql, resetDemo, root } from '../scripts/db.mjs'

// 本脚本只重置独立测试库，必须将被测服务连接到 club_manage_test。
const base = process.env.TEST_API || 'http://localhost:18081/api'
if (!/^http:\/\/(localhost|127\.0\.0\.1):18081\/api$/.test(base)) throw new Error('测试仅允许本机 18081 端口')
const tokens = {}, results = [], extras = [], traces = []
const hash = text => createHash('sha256').update(text).digest('hex')
const db = text => sql(`USE club_manage_test; ${text}`)
const count = text => Number(db(text))
async function request(user, method, route, body, expected = 0) {
  const response = await fetch(base + route, { method, headers: { 'Content-Type': 'application/json', ...(tokens[user] ? { Authorization: `Bearer ${tokens[user]}` } : {}) }, ...(body === undefined ? {} : { body: JSON.stringify(body) }) })
  const value = await response.json()
  traces.push({ method, route, code: value.code })
  assert.equal(value.code, expected, `${method} ${route}: ${JSON.stringify(value)}`)
  return expected ? value : value.data
}
const get = (u, p, code = 0) => request(u, 'GET', p, undefined, code)
const post = (u, p, b, code = 0) => request(u, 'POST', p, b, code)
const audit = (u, path, result = 'agree', code = 0) => post(u, path, { result }, code)
const join = async (u = '2021010') => (await post(u, '/clubs/1/join-applies')).applyId
const dissolve = async () => (await post('2021006', '/clubs/1/dissolve-applies')).dissolveApplyId
const createBody = name => ({ clubName: name, clubDesc: '五位同学共同创立的校园摄影社团', applyTeaId: 'T001', stuIds: ['2021001','2021002','2021003','2021004','2021005'] })
const create = async (name = '摄影社') => (await post('2021001', '/create-applies', createBody(name))).createApplyId
const activityBody = { actName: '迎新杯', actDesc: '社团迎新比赛', actStartTime: '2026-10-01 14:00:00', actEndTime: '2026-10-01 18:00:00', actPlace: '体育馆' }
const activity = async () => (await post('2021006', '/clubs/1/activities', activityBody)).actId
async function createApproved() { const id = await create(); await audit('2021007', `/union/create-applies/${id}/audit`); await audit('T001', `/teacher/create-applies/${id}/audit`); return id }
async function dissolved() { const id = await dissolve(); await audit('2021007', `/union/dissolve-applies/${id}/audit`); await audit('T003', `/teacher/dissolve-applies/${id}/audit`); return id }
function member(stuId, role = 'member') { db(`INSERT INTO club_member(club_id,stu_id,member_role) VALUES(1,'${stuId}','${role}');`) }
async function run(id, title, fn, list = results) {
  const begin = Date.now()
  try { resetDemo(); await fn(); list.push({ id, title, status: '通过', ms: Date.now() - begin }); console.log(`通过 ${id} ${title}`) }
  catch (error) { list.push({ id, title, status: '失败', error: error.message, ms: Date.now() - begin }); console.error(`失败 ${id} ${title}: ${error.message}`) }
}
resetDemo()
for (const account of ['2021001','2021002','2021003','2021004','2021005','2021006','2021007','2021008','2021009','2021010','T001','T002','T003']) {
  const value = await post('', '/auth/login', { userType: account.startsWith('T') ? 'teacher' : 'student', account, password: hash('123456') })
  tokens[account] = value.token
}
await run(1, '学生登录与复合身份', async () => { const r = await get('2021006','/auth/profile'); assert.equal(r.club.clubRole,'president'); assert.equal(r.unionMember,true) })
await run(2, '教师登录', async () => { const r = await get('T003','/auth/profile'); assert.equal(r.userType,'teacher'); assert.equal(r.club,null) })
await run(3, '错误密码', async () => { const r = await post('', '/auth/login', { userType:'student',account:'2021006',password:hash('wrong') },1001); assert.equal(r.message,'账号或密码错误') })
await run(4, '社团列表', async () => { const r = await get('2021010','/clubs'); assert.equal(r[0].teaName,'杨老师'); assert.equal(r[0].memberCount,3) })
await run(5, '解散后不可见', async () => { await dissolved(); assert.equal((await get('2021010','/clubs')).length,0) })
await run(6, '正常提交入社', async () => { const id=await join(); assert.equal(db(`SELECT apply_status FROM join_apply WHERE apply_id=${id}`),'pending') })
await run(7, '已入社拒绝', async () => { const r=await post('2021009','/clubs/1/join-applies',undefined,1001); assert.equal(r.message,'您已加入社团，不可再提交入社申请') })
await run(8, '在途申请拒绝', async () => { await join(); const r=await post('2021010','/clubs/1/join-applies',undefined,1001); assert.equal(r.message,'您已有待审批的入社申请，请等待审批结果后再提交') })
await run(9, '解散冻结入社', async () => { await dissolve(); const r=await post('2021010','/clubs/1/join-applies',undefined,1001); assert.equal(r.message,'该社团正在解散审批中，暂停入社申请') })
await run(10, '同意自动入社与审批人', async () => { const id=await join(); await audit('2021006',`/join-applies/${id}/audit`); assert.equal(count("SELECT COUNT(*) FROM club_member WHERE stu_id='2021010' AND leave_time IS NULL"),1); assert.equal(db(`SELECT approve_stu_id FROM join_apply WHERE apply_id=${id}`),'2021006') })
await run(11, '拒绝不入社', async () => { const id=await join(); await audit('2021006',`/join-applies/${id}/audit`,'reject'); assert.equal(count("SELECT COUNT(*) FROM club_member WHERE stu_id='2021010'"),0) })
await run(12, '同意冲突回滚', async () => { const id=await join(); member('2021010'); const r=await audit('2021006',`/join-applies/${id}/audit`,'agree',1002); assert.equal(r.message,'该学生已加入其他社团，审批已回滚'); assert.equal(db(`SELECT apply_status FROM join_apply WHERE apply_id=${id}`),'pending') })
await run(13, '副社长审批平权', async () => { const id=await join(); await audit('2021008',`/join-applies/${id}/audit`); assert.equal(db(`SELECT approve_stu_id FROM join_apply WHERE apply_id=${id}`),'2021008') })
await run(14, '主动退社留痕', async () => { const r=await post('2021009','/members/my/quit'); assert.match(r.leaveTime,/^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/); assert.equal(db("SELECT CONCAT(leave_type,':',operate_stu_id) FROM club_member WHERE stu_id='2021009'"),'quit:2021009') })
await run(15, '踢出留痕', async () => { await post('2021008','/clubs/1/members/2021009/kick'); assert.equal(db("SELECT CONCAT(leave_type,':',operate_stu_id) FROM club_member WHERE stu_id='2021009'"),'kick:2021008') })
await run(16, '不能踢出社长', async () => { await post('2021008','/clubs/1/members/2021006/kick',undefined,1001) })
await run(17, '晋升副社长及日志', async () => { const r=await post('2021006','/clubs/1/role-change',{stuId:'2021009',newRole:'vice_president'}); assert.equal(r.oldRole,'member'); assert.equal(count('SELECT COUNT(*) FROM club_member_change_log'),1) })
await run(18, '第三名副社长被拦截', async () => { member('2021010'); await post('2021006','/clubs/1/role-change',{stuId:'2021009',newRole:'vice_president'}); const r=await post('2021006','/clubs/1/role-change',{stuId:'2021010',newRole:'vice_president'},1001); assert.equal(r.message,'该社团在职副社长已达2名上限') })
await run(19, '双社长触发器拦截', async () => { const r=await post('2021006','/clubs/1/role-change',{stuId:'2021009',newRole:'president'},1001); assert.equal(r.message,'该社团已存在在职正社长，不可重复设置') })
await run(20, '换届原子成功', async () => { const r=await post('2021006','/clubs/1/change-president',{demoteStuIds:['2021006'],newPresidentStuId:'2021008'}); assert.equal(r.changes.length,2); assert.equal(db("SELECT member_role FROM club_member WHERE stu_id='2021008'"),'president'); assert.equal(count("SELECT COUNT(*) FROM club_member_change_log WHERE operate_stu_id='2021006'"),2) })
await run(21, '漏降级整笔回滚', async () => { await post('2021006','/clubs/1/change-president',{demoteStuIds:['2021008'],newPresidentStuId:'2021009'},1001); assert.equal(db("SELECT member_role FROM club_member WHERE stu_id='2021008'"),'vice_president'); assert.equal(count('SELECT COUNT(*) FROM club_member_change_log'),0) })
await run(22, '换届目标非社员', async () => { const r=await post('2021006','/clubs/1/change-president',{demoteStuIds:['2021006'],newPresidentStuId:'2021010'},1001); assert.equal(r.message,'目标学生不是本社团在职社员'); assert.equal(db("SELECT member_role FROM club_member WHERE stu_id='2021006'"),'president') })
await run(23, '五人建团完整闭环', async () => { const id=await createApproved(); assert.equal(db(`SELECT final_status FROM club_create_apply WHERE create_apply_id=${id}`),'success'); assert.equal(count("SELECT COUNT(*) FROM club_member m JOIN club c ON c.club_id=m.club_id WHERE c.club_name='摄影社'"),5); assert.equal(db("SELECT GROUP_CONCAT(member_role ORDER BY stu_id) FROM club_member WHERE stu_id IN ('2021001','2021002','2021003','2021004','2021005')"),'president,vice_president,vice_president,member,member') })
await run(24, '学生会驳回建团', async () => { const id=await create(); await audit('2021007',`/union/create-applies/${id}/audit`,'reject'); assert.equal(db(`SELECT final_status FROM club_create_apply WHERE create_apply_id=${id}`),'fail') })
await run(25, '教师驳回建团', async () => { const id=await create(); await audit('T001',`/teacher/create-applies/${id}/audit`,'reject'); assert.equal(db(`SELECT final_status FROM club_create_apply WHERE create_apply_id=${id}`),'fail') })
await run(26, '重名终审回滚', async () => { const id=await create(); db("UPDATE club SET club_name='摄影社' WHERE club_id=1"); await audit('2021007',`/union/create-applies/${id}/audit`); await audit('T001',`/teacher/create-applies/${id}/audit`,'agree',1002); assert.equal(db(`SELECT CONCAT(final_status,':',tea_audit_status) FROM club_create_apply WHERE create_apply_id=${id}`),'pending:pending') })
await run(27, '发起人入他社后终审回滚', async () => { const id=await create(); member('2021004'); await audit('2021007',`/union/create-applies/${id}/audit`); await audit('T001',`/teacher/create-applies/${id}/audit`,'agree',1002); assert.equal(count("SELECT COUNT(*) FROM club WHERE club_name='摄影社'"),0); assert.equal(db(`SELECT tea_audit_status FROM club_create_apply WHERE create_apply_id=${id}`),'pending') })
await run(28, '教师被抢占回滚', async () => { const a=await create('摄影社'); const b=await create('读书社'); await audit('2021007',`/union/create-applies/${a}/audit`); await audit('T001',`/teacher/create-applies/${a}/audit`); await audit('2021007',`/union/create-applies/${b}/audit`); await audit('T001',`/teacher/create-applies/${b}/audit`,'agree',1002); assert.equal(db(`SELECT tea_audit_status FROM club_create_apply WHERE create_apply_id=${b}`),'pending') })
await run(29, '四人建团拒绝', async () => { const body=createBody('摄影社'); body.stuIds.pop(); await post('2021001','/create-applies',body,400) })
await run(30, '建团发起人已有社团', async () => { const body=createBody('摄影社'); body.stuIds[4]='2021009'; await post('2021001','/create-applies',body,1001) })
await run(31, '学生会成员平权审批', async () => { const id=await create(); await audit('2021006',`/union/create-applies/${id}/audit`); assert.equal(db(`SELECT union_audit_stu_id FROM club_create_apply WHERE create_apply_id=${id}`),'2021006') })
await run(32, '活动申办', async () => { const id=await activity(); assert.equal(db(`SELECT act_status FROM club_activity WHERE act_id=${id}`),'wait_audit') })
await run(33, '解散冻结活动申办', async () => { await dissolve(); await post('2021008','/clubs/1/activities',activityBody,1001) })
await run(34, '指导教师同意活动', async () => { const id=await activity(); await audit('T003',`/teacher/activities/${id}/audit`); assert.equal(db(`SELECT act_status FROM club_activity WHERE act_id=${id}`),'running') })
await run(35, '非绑定教师拒绝', async () => { const id=await activity(); await audit('T001',`/teacher/activities/${id}/audit`,'agree',403) })
await run(36, '管理层完结活动', async () => { const id=await activity(); await audit('T003',`/teacher/activities/${id}/audit`); await post('2021008',`/clubs/1/activities/${id}/finish`); assert.equal(db(`SELECT act_status FROM club_activity WHERE act_id=${id}`),'finish') })
await run(37, '仅社长发起解散', async () => { const r=await post('2021008','/clubs/1/dissolve-applies',undefined,1001); assert.equal(r.message,'仅社团社长可发起解散申请') })
await run(38, '重复解散申请', async () => { await dissolve(); const r=await post('2021006','/clubs/1/dissolve-applies',undefined,1001); assert.equal(r.message,'该社团已有待审批的解散申请，不可重复发起') })
await run(39, '解散删除并释放身份', async () => { await join(); await post('2021006','/clubs/1/role-change',{stuId:'2021009',newRole:'vice_president'}); await dissolved(); for(const table of ['club','club_member','join_apply','club_notice','club_activity','club_member_change_log','club_dissolve_apply']) assert.equal(count(`SELECT COUNT(*) FROM ${table}`),0,table); assert.equal((await get('2021006','/auth/profile')).club,null); assert.equal((await get('T003','/teacher/club')),null) })
await run(40, '解散驳回保留社团', async () => { const id=await dissolve(); await audit('2021007',`/union/dissolve-applies/${id}/audit`,'reject'); assert.equal(count('SELECT COUNT(*) FROM club'),1); assert.equal(db(`SELECT final_status FROM club_dissolve_apply WHERE dissolve_apply_id=${id}`),'fail'); await join() })
await run(41, '公告发布编辑软删除', async () => { const r=await post('2021008','/clubs/1/notices',{noticeTitle:'测试公告',noticeContent:'正文'}); await request('2021006','PUT',`/clubs/1/notices/${r.noticeId}`,{noticeTitle:'已编辑',noticeContent:'新正文'}); assert.ok((await get('2021010','/clubs/1')).notices.some(n=>n.noticeId===r.noticeId)); await request('2021008','DELETE',`/clubs/1/notices/${r.noticeId}`); assert.equal(count(`SELECT is_deleted FROM club_notice WHERE notice_id=${r.noticeId}`),1); assert.ok(!(await get('2021010','/clubs/1')).notices.some(n=>n.noticeId===r.noticeId)); assert.ok((await get('2021006','/clubs/1/notices')).some(n=>n.noticeId===r.noticeId)) })
await run(42, '消息发布身份限制', async () => { await post('2021009','/messages',{msgTitle:'越权',msgContent:'正文'},403) })
await run(43, '系统消息软删除', async () => { const r=await post('2021007','/messages',{msgTitle:'消息',msgContent:'正文'}); await request('2021006','PUT',`/messages/${r.msgId}`,{msgTitle:'已编辑',msgContent:'新正文'}); await request('2021007','DELETE',`/messages/${r.msgId}`); assert.equal(count(`SELECT is_deleted FROM system_message WHERE msg_id=${r.msgId}`),1); assert.ok(!(await get('T001','/messages')).some(n=>n.msgId===r.msgId)) })
await run(44, '新增学生会成员和日志', async () => { await post('2021007','/union/members',{stuId:'2021010'}); assert.equal(count("SELECT COUNT(*) FROM student_union_member WHERE stu_id='2021010'"),1); assert.equal(db("SELECT operate_type FROM student_union_operate_log WHERE stu_id='2021010'"),'add') })
await run(45, '移除学生会成员和日志', async () => { await request('2021007','DELETE','/union/members/2021006'); assert.equal(count("SELECT COUNT(*) FROM student_union_member WHERE stu_id='2021006'"),0); assert.equal(db("SELECT operate_type FROM student_union_operate_log WHERE stu_id='2021006' ORDER BY log_id DESC LIMIT 1"),'remove') })
await run(46, '最后一名学生会成员保护', async () => { await request('2021007','DELETE','/union/members/2021006'); const r=await request('2021007','DELETE','/union/members/2021007',undefined,1001); assert.equal(r.message,'学生会至少保留一名成员') })
await run(47, '概览视图人数准确', async () => { const id=await join(); await audit('2021006',`/join-applies/${id}/audit`); assert.equal((await get('2021006','/clubs/my')).memberCount,4); assert.equal(count('SELECT member_count FROM v_club_info WHERE club_id=1'),4) })
await run(48, '审批台视图仅返回待审', async () => { const id=await join(); assert.equal((await get('2021006','/clubs/1/join-applies')).length,1); await audit('2021006',`/join-applies/${id}/audit`,'reject'); assert.equal((await get('2021006','/clubs/1/join-applies')).length,0) })
await run(49, '档案包含在社和历史', async () => { await post('2021009','/members/my/quit'); const id=await join('2021009'); await audit('2021006',`/join-applies/${id}/audit`); const r=await get('2021009','/members/my'); assert.equal(r.length,2); assert.ok(r.some(x=>x.leaveType==='quit')); assert.ok(r.some(x=>x.leaveTime===null)) })
await run(50, '原审批视图字段限制与替代更新验证', async () => {
  const id=await join(); assert.throws(()=>db(`UPDATE v_join_apply_pending SET apply_status='agree' WHERE apply_id=${id}`),/1054/)
  db(`UPDATE v_join_apply_pending SET apply_time='2026-09-20 10:00:00' WHERE apply_id=${id}`)
  assert.equal(db(`SELECT apply_time FROM join_apply WHERE apply_id=${id}`),'2026-09-20 10:00:00')
  await audit('2021006',`/join-applies/${id}/audit`)
  db("UPDATE v_stu_club_record SET leave_time=NOW(),leave_type='quit',operate_stu_id='2021010' WHERE stu_id='2021010' AND leave_time IS NULL")
  assert.equal(count("SELECT COUNT(*) FROM club_member WHERE stu_id='2021010' AND leave_type='quit'"),1)
  db("UPDATE v_club_member_detail SET member_role='vice_president' WHERE stu_id='2021009'")
  assert.equal(db("SELECT member_role FROM club_member WHERE stu_id='2021009'"),'vice_president')
})
await run(51, '历史建团审批双方信息', async () => { const id=await createApproved(); const r=(await get('2021007','/union/audit-records')).find(x=>x.createApplyId===id); assert.equal(r.unionAuditStuId,'2021007'); assert.ok(r.unionAuditTime); assert.ok(r.teaAuditTime); assert.equal(r.initiators.length,5); await dissolved(); assert.equal((await get('2021007','/union/dissolve-applies')).length,0) })
await run(52, '外键阻止直接删除社团', async () => { assert.throws(()=>db('DELETE FROM club WHERE club_id=1'),/1451/); assert.equal(count('SELECT COUNT(*) FROM club'),1) })
await run(53, '外键阻止删除学生', async () => { assert.throws(()=>db("DELETE FROM student WHERE stu_id='2021006'"),/1451/) })
await run(54, '解散过程幂等保护', async () => { const id=await dissolved(); assert.throws(()=>db(`CALL sp_dissolve_club(${id})`),/解散申请不存在或未通过双审批/) })
await run(55, '并发审批仅一次成功', async () => { const id=await join(); const values=await Promise.all(['2021006','2021008'].map(async u => { const r=await fetch(`${base}/join-applies/${id}/audit`,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${tokens[u]}`},body:JSON.stringify({result:'agree'})}); return r.json() })); assert.deepEqual(values.map(r=>r.code).sort((a,b)=>a-b),[0,404]); assert.equal(values.find(r=>r.code===404).message,'该申请已被处理'); assert.equal(count("SELECT COUNT(*) FROM club_member WHERE stu_id='2021010'"),1) })

await run('E1','全部查询接口与实时权限',async()=>{
  const routes={ '2021006':['/clubs/my','/clubs/1/members','/clubs/1/members/history','/clubs/1/activities/all','/clubs/1/dissolve-applies','/union/member-logs'], '2021010':['/auth/personal','/teachers/free','/join-applies/my','/members/my','/members/my/role-logs','/create-applies/my'], '2021007':['/union/create-applies','/union/dissolve-applies','/union/members'], T003:['/teacher/create-applies','/teacher/dissolve-applies','/teacher/activities','/teacher/club'], '2021009':['/clubs/1/activities'] }
  for(const [u,paths] of Object.entries(routes)) for(const p of paths) await get(u,p)
  await get('','/clubs',401); await get('2021010','/clubs/1/members',403); await get('2021007','/clubs/1/activities',403)
  await request('2021007','DELETE','/union/members/2021006'); await get('2021006','/union/members',403); assert.equal((await get('2021006','/auth/profile')).unionMember,false)
},extras)
await run('E2','先教师后学生会同意仍完成闭环',async()=>{const id=await create(); await audit('T001',`/teacher/create-applies/${id}/audit`); assert.equal(db(`SELECT final_status FROM club_create_apply WHERE create_apply_id=${id}`),'pending'); await audit('2021007',`/union/create-applies/${id}/audit`); assert.equal(db(`SELECT final_status FROM club_create_apply WHERE create_apply_id=${id}`),'success'); const d=await dissolve(); await audit('T003',`/teacher/dissolve-applies/${d}/audit`); await audit('2021007',`/union/dissolve-applies/${d}/audit`); assert.equal(count('SELECT COUNT(*) FROM club WHERE club_id=1'),0)},extras)
await run('E3','无副社长时换届权限桥接',async()=>{await post('2021006','/clubs/1/role-change',{stuId:'2021008',newRole:'member'}); const before=count('SELECT COUNT(*) FROM club_member_change_log'); await post('2021006','/clubs/1/change-president',{demoteStuIds:['2021006'],newPresidentStuId:'2021009'}); assert.equal(db("SELECT member_role FROM club_member WHERE stu_id='2021009'"),'president'); assert.equal(count('SELECT COUNT(*) FROM club_member_change_log'),before+2); assert.equal(db("SELECT member_role FROM club_member WHERE stu_id='2021008'"),'member')},extras)
await run('E4','换届全部管理层降级',async()=>{await post('2021006','/clubs/1/change-president',{demoteStuIds:['2021006','2021008'],newPresidentStuId:'2021009'}); assert.equal(count("SELECT COUNT(*) FROM club_member WHERE member_role='president'"),1); assert.equal(count("SELECT COUNT(*) FROM club_member WHERE member_role='vice_president'"),0); assert.equal(count('SELECT COUNT(*) FROM club_member_change_log'),3)},extras)
await run('E5','并发提交入社不产生两条在途',async()=>{const codes=await Promise.all([1,2].map(async()=>{const r=await fetch(base+'/clubs/1/join-applies',{method:'POST',headers:{Authorization:`Bearer ${tokens['2021010']}`}});return(await r.json()).code}));assert.deepEqual(codes.sort((a,b)=>a-b),[0,1001]);assert.equal(count("SELECT COUNT(*) FROM join_apply WHERE stu_id='2021010' AND apply_status='pending'"),1)},extras)
await run('E6','密码修改及输入校验',async()=>{await request('2021010','PUT','/auth/password',{oldPassword:hash('123456'),newPassword:hash('654321')}); await post('','/auth/login',{userType:'student',account:'2021010',password:hash('123456')},1001); await post('','/auth/login',{userType:'student',account:'2021010',password:hash('654321')}); await post('2021006','/clubs/1/activities',{...activityBody,actEndTime:'2026-02-30 12:00:00'},400); await post('2021006','/clubs/1/role-change',{stuId:'2021009',newRole:'admin'},400)},extras)
await run('E7','教师提前同意后的冲突恢复学生会状态',async()=>{const id=await create();await audit('T001',`/teacher/create-applies/${id}/audit`);member('2021004');await audit('2021007',`/union/create-applies/${id}/audit`,'agree',1002);assert.equal(db(`SELECT CONCAT(union_audit_status,':',tea_audit_status,':',final_status) FROM club_create_apply WHERE create_apply_id=${id}`),'pending:agree:pending')},extras)

await run('E8','两人管理层同时降级后原副社长接任',async()=>{await post('2021006','/clubs/1/members/2021009/kick');await post('2021006','/clubs/1/change-president',{demoteStuIds:['2021006','2021008'],newPresidentStuId:'2021008'});assert.equal(db("SELECT member_role FROM club_member WHERE stu_id='2021008' AND leave_time IS NULL"),'president');assert.equal(db("SELECT member_role FROM club_member WHERE stu_id='2021006' AND leave_time IS NULL"),'member');assert.equal(count('SELECT COUNT(*) FROM club_member_change_log'),3)},extras)
await run('E9','重复审批、越权审批及活动驳回',async()=>{const id=await create();await audit('T002',`/teacher/create-applies/${id}/audit`,'agree',403);await audit('2021009',`/union/create-applies/${id}/audit`,'agree',403);await audit('2021007',`/union/create-applies/${id}/audit`);await audit('2021007',`/union/create-applies/${id}/audit`,'agree',404);const a=await activity();await audit('T003',`/teacher/activities/${a}/audit`,'reject');await post('2021006',`/clubs/1/activities/${a}/finish`,undefined,404);await get('2021010','/clubs/999999',404);await post('2021007','/union/members',{stuId:'2021007'},1002)},extras)

// 结果由实际断言生成，原第50例的定义冲突单独标注，不伪报通过。
const source=readFileSync(path.join(root,'docs/dev/05-测试文档.md'),'utf8').split('## 4 端到端演示剧本')[0]
const expectations=new Map([...source.matchAll(/^\|\s*(\d+)\s*\|\s*([^|]+)\|\s*([^|]+)\|\s*([^|]+)\|/gm)].map(m=>[Number(m[1]),m[4].trim()]))
const escape=value=>String(value||'').replaceAll('|','\\|').replaceAll('\n',' ')
const passed=results.filter(r=>r.status==='通过' && r.id!==50).length
const report=['# 测试执行结果',`\n执行时间：${new Date().toISOString()}。服务：${base}；数据库：club_manage_test。`, `\n原55例：${passed}例通过；第50例受原视图字段限制，已执行替代验证；${results.filter(r=>r.status==='失败').length}例失败。`, '\n|编号|用例|文档预期|实际结果|状态|','|---|---|---|---|---|', ...results.map(r=>`|${r.id}|${r.title}|${escape(expectations.get(r.id))}|${r.id===50?'原UPDATE实测1054；三个可更新视图实际字段更新及入社触发联动均验证通过':escape(r.error)||'HTTP响应与数据库断言符合预期'}|${r.id===50&&r.status==='通过'?'原例受限 / 替代验证通过':r.status}|`),'\n## 补充边界验证','\n|编号|用例|状态|详情|','|---|---|---|---|',...extras.map(r=>`|${r.id}|${r.title}|${r.status}|${escape(r.error)||'断言通过'}|`),'\n## 第50例说明','\n原 v_join_apply_pending 只暴露 apply_id、club_id、club_name、stu_id、stu_name、stu_class、stu_phone、apply_time，没有 apply_status、approve_stu_id、reply_time。因此不能通过它更新审批状态。遵守数据库对象不可修改约束，保留原定义；实际更新其 apply_time，并测试 v_stu_club_record 与 v_club_member_detail 的可更新字段。审批状态仍通过 join_apply 条件更新并由原触发器完成联动。']
writeFileSync(path.join(root,'test/expected-results.md'),report.join('\n'))
writeFileSync(path.join(root,'test/results.json'),JSON.stringify({date:new Date().toISOString(),results,extras,traces},null,2))
resetDemo()
console.log(`完成：原用例通过 ${passed}/54，第50例替代验证 ${results.find(r=>r.id===50)?.status}；补充 ${extras.filter(r=>r.status==='通过').length}/${extras.length}`)
if([...results,...extras].some(r=>r.status==='失败')) process.exitCode=1
