-- ============================================================
-- 数据库触发器脚本（need.md 要求3：触发器等数据库对象）
-- 数据库：club_manage
--
-- 触发器清单：
--   1. trg_club_member_role_insert    1正2副角色数量校验（新增社员时）
--   2. trg_club_member_role_update    1正2副角色数量校验（晋升/降级/换届时）
--   3. trg_join_apply_audit           入社申请审批联动（同意自动入社）
--
-- 说明：原触发器4 trg_club_create_finalize（建团双审批通过联动）
--       已按评审决策 A2 删除，联动逻辑改由后端显式调用存储过程
--       sp_create_club 完成（见 procedures.sql）。
-- ============================================================
USE club_manage;

-- ------------------------------------------------------------
-- 1. 社团角色数量校验（新增社员时）
--    需求约束3：单个社团仅允许 1名正社长、最多2名副社长
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_club_member_role_insert;
DELIMITER $$
CREATE TRIGGER trg_club_member_role_insert
    BEFORE INSERT
    ON club_member
    FOR EACH ROW
BEGIN
    IF NEW.member_role = 'president' THEN
        IF EXISTS (SELECT 1
                   FROM club_member
                   WHERE club_id = NEW.club_id
                     AND member_role = 'president'
                     AND leave_time IS NULL
                     AND member_id <> NEW.member_id) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '该社团已存在在职正社长，不可重复设置';
        END IF;
    ELSEIF NEW.member_role = 'vice_president' THEN
        IF (SELECT COUNT(*)
            FROM club_member
            WHERE club_id = NEW.club_id
              AND member_role = 'vice_president'
              AND leave_time IS NULL
              AND member_id <> NEW.member_id) >= 2 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '该社团在职副社长已达2名上限';
        END IF;
    END IF;
END$$
DELIMITER ;

-- ------------------------------------------------------------
-- 2. 社团角色数量校验（角色变更时：晋升/降级/社长换届）
--    说明：应用层先降级原角色再晋升新角色（或相反顺序），
--          本触发器保证任意时刻 1正2副 约束不被破坏
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_club_member_role_update;
DELIMITER $$
CREATE TRIGGER trg_club_member_role_update
    BEFORE UPDATE
    ON club_member
    FOR EACH ROW
BEGIN
    IF NEW.member_role <> OLD.member_role AND NEW.leave_time IS NULL THEN
        IF NEW.member_role = 'president' THEN
            IF EXISTS (SELECT 1
                       FROM club_member
                       WHERE club_id = NEW.club_id
                         AND member_role = 'president'
                         AND leave_time IS NULL
                         AND member_id <> NEW.member_id) THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '该社团已存在在职正社长，不可重复设置';
            END IF;
        ELSEIF NEW.member_role = 'vice_president' THEN
            IF (SELECT COUNT(*)
                FROM club_member
                WHERE club_id = NEW.club_id
                  AND member_role = 'vice_president'
                  AND leave_time IS NULL
                  AND member_id <> NEW.member_id) >= 2 THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '该社团在职副社长已达2名上限';
            END IF;
        END IF;
    END IF;
END$$
DELIMITER ;

-- ------------------------------------------------------------
-- 3. 入社申请审批联动触发器（需求5.2：学生入社闭环流程）
--    应用层仅需将 join_apply.apply_status 由 pending 更新为
--    agree（同时更新 reply_time 与审批人 approve_stu_id），本触发器自动完成：
--      agree → 自动新增社员记录（默认普通社员）
--    若学生已在其他社团（uk_stu_active 唯一约束），同意操作将
--    被数据库唯一约束拦截并整体回滚，保证需求约束2不被破坏
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_join_apply_audit;
DELIMITER $$
CREATE TRIGGER trg_join_apply_audit
    AFTER UPDATE
    ON join_apply
    FOR EACH ROW
BEGIN
    -- 仅处理 pending → agree 的审批动作，避免重复触发
    IF OLD.apply_status = 'pending' AND NEW.apply_status = 'agree' THEN
        -- 同意：自动新增社员记录
        INSERT INTO club_member (club_id, stu_id, member_role)
        VALUES (NEW.club_id, NEW.stu_id, 'member');
    END IF;
END$$
DELIMITER ;
