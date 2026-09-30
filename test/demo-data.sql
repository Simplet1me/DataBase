-- 通用演示数据。仅在本项目演示库执行，会清理该库现有业务数据；可重复执行。
-- 2021001 张三、2021002 李四、2021003 王五、2021004 赵六、2021005 孙七：五人建团组。
-- 2021006 周八：篮球社社长兼学生会；2021007 吴九：学生会审批人。
-- 2021008 郑十：篮球社副社长和换届目标；2021009 冯十一：普通社员退社演示。
-- 2021010 陈十二：无社团，入社申请演示。T001 刘老师、T002 陈老师空闲；T003 杨老师指导篮球社。
-- 密码统一为 123456 的 SHA-256，数据库仅保存哈希。
USE club_manage;
START TRANSACTION;
DELETE FROM club_member_change_log;
DELETE FROM join_apply;
DELETE FROM club_activity;
DELETE FROM club_notice;
DELETE FROM club_dissolve_apply;
DELETE FROM club_member;
DELETE FROM club_create_apply_member;
DELETE FROM club_create_apply;
DELETE FROM club;
DELETE FROM system_message;
DELETE FROM student_union_operate_log;
DELETE FROM student_union_member;
DELETE FROM student;
DELETE FROM teacher;
INSERT INTO student(stu_id,stu_name,stu_gender,stu_class,stu_phone,stu_pwd) VALUES
('2021001','张三','男','计算机2101','13800000001',SHA2('123456',256)),
('2021002','李四','女','计算机2101','13800000002',SHA2('123456',256)),
('2021003','王五','男','计算机2101','13800000003',SHA2('123456',256)),
('2021004','赵六','女','计算机2101','13800000004',SHA2('123456',256)),
('2021005','孙七','男','计算机2101','13800000005',SHA2('123456',256)),
('2021006','周八','男','软件2102','13800000006',SHA2('123456',256)),
('2021007','吴九','女','软件2102','13800000007',SHA2('123456',256)),
('2021008','郑十','男','软件2102','13800000008',SHA2('123456',256)),
('2021009','冯十一','女','软件2102','13800000009',SHA2('123456',256)),
('2021010','陈十二','男','软件2102','13800000010',SHA2('123456',256));
INSERT INTO teacher(tea_id,tea_name,tea_phone,tea_pwd) VALUES
('T001','刘老师','13900000001',SHA2('123456',256)),
('T002','陈老师','13900000002',SHA2('123456',256)),
('T003','杨老师','13900000003',SHA2('123456',256));
INSERT INTO student_union_member(stu_id) VALUES('2021006'),('2021007');
INSERT INTO student_union_operate_log(stu_id,operate_type,operate_stu_id) VALUES('2021006','add','2021007'),('2021007','add','2021006');
INSERT INTO club(club_id,club_name,club_desc,club_create_time,tea_id) VALUES
(1,'篮球社','在球场相遇，与热爱同行。每周开展训练、友谊赛和校园联赛，欢迎每一位热爱运动的同学。','2026-09-01 09:00:00','T003');
INSERT INTO club_member(club_id,stu_id,member_role) VALUES(1,'2021006','president'),(1,'2021008','vice_president'),(1,'2021009','member');
INSERT INTO club_activity(club_id,act_name,act_desc,act_start_time,act_end_time,act_place,act_status,audit_tea_id,audit_time) VALUES
(1,'秋日篮球友谊赛','一起上场，享受运动。请携带运动装备和饮用水。','2026-10-01 14:00:00','2026-10-01 18:00:00','学校体育馆','running','T003',NOW());
INSERT INTO club_notice(club_id,notice_title,notice_content,publish_stu_id) VALUES
(1,'新学期训练安排','每周三与周五 17:00，在东区篮球场集合。欢迎社员参加。','2021006'),
(1,'社团招新进行中','零基础也欢迎。和我们一起训练，找到属于你的队友。','2021008');
INSERT INTO system_message(publish_stu_id,msg_title,msg_content) VALUES
('2021007','新学期，找到你的热爱','社团招新正式开始。前往社团广场探索感兴趣的社团，提交申请后可在个人中心查看进度。'),
('2021007','校园社团活动申办提醒','活动由本社团管理层发起，经指导教师审批后开展。请提前填写活动时间、地点与内容。');
COMMIT;
