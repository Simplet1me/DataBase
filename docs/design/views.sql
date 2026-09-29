-- ============================================================
-- 视图脚本（need.md 要求6：定义视图，实现视图的查询与更新）
-- 数据库：club_manage
--
-- 视图清单：
--   1. v_club_info              社团概览（社团 + 指导教师 + 在职社员数）    仅供查询
--   2. v_join_apply_pending     待审批入社申请（审批台）                    可查询/可更新
--   3. v_stu_club_record        学生社团档案（入退社历史 + 角色）           可查询/可更新
--   4. v_club_member_detail     社团在职社员明细（管理层社员管理）          可查询/可更新
--
-- 说明：2/3/4 号视图基于简单多表连接（无聚合、无 DISTINCT），
--       满足 MySQL 可更新视图规则，可直接通过视图执行 UPDATE；
--       更新仅作用于视图所属单表字段时生效。
-- ============================================================
USE club_manage;

-- ------------------------------------------------------------
-- 1. 社团概览视图：社团基本信息 + 指导教师姓名 + 在职社员数
--    （含子查询统计，仅供查询）
-- ------------------------------------------------------------
DROP VIEW IF EXISTS v_club_info;
CREATE VIEW v_club_info AS
SELECT c.club_id,
       c.club_name,
       c.club_desc,
       c.club_create_time,
       c.tea_id,
       t.tea_name                   AS tea_name,
       (SELECT COUNT(*)
        FROM club_member m
        WHERE m.club_id = c.club_id
          AND m.leave_time IS NULL) AS member_count
FROM club c
         LEFT JOIN teacher t ON c.tea_id = t.tea_id;

-- ------------------------------------------------------------
-- 2. 待审批入社申请视图：正/副社长审批台查询
-- ------------------------------------------------------------
DROP VIEW IF EXISTS v_join_apply_pending;
CREATE VIEW v_join_apply_pending AS
SELECT a.apply_id,
       a.club_id,
       c.club_name,
       a.stu_id,
       s.stu_name,
       s.stu_class,
       s.stu_phone,
       a.apply_time
FROM join_apply a
         JOIN club c ON a.club_id = c.club_id
         JOIN student s ON a.stu_id = s.stu_id
WHERE a.apply_status = 'pending';

-- ------------------------------------------------------------
-- 3. 学生社团档案视图：个人入退社历史与角色记录（需求4.1.8）
-- ------------------------------------------------------------
DROP VIEW IF EXISTS v_stu_club_record;
CREATE VIEW v_stu_club_record AS
SELECT m.member_id,
       m.stu_id,
       s.stu_name,
       m.club_id,
       c.club_name,
       m.member_role,
       m.join_time,
       m.leave_time,
       m.leave_type,
       m.operate_stu_id
FROM club_member m
         JOIN student s ON m.stu_id = s.stu_id
         JOIN club c ON m.club_id = c.club_id;

-- ------------------------------------------------------------
-- 4. 社团在职社员视图：管理层社员信息管理（需求4.2.1）
-- ------------------------------------------------------------
DROP VIEW IF EXISTS v_club_member_detail;
CREATE VIEW v_club_member_detail AS
SELECT m.member_id,
       m.club_id,
       c.club_name,
       m.stu_id,
       s.stu_name,
       s.stu_class,
       s.stu_phone,
       m.member_role,
       m.join_time
FROM club_member m
         JOIN student s ON m.stu_id = s.stu_id
         JOIN club c ON m.club_id = c.club_id
WHERE m.leave_time IS NULL;
