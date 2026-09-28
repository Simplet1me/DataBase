-- ============================================================
-- 数据库触发器脚本（need.md 要求3：触发器等数据库对象）
-- 数据库：club_manage
--
-- 触发器清单：
--   1. trg_club_member_role_insert    1正2副角色数量校验（新增社员时）
--   2. trg_club_member_role_update    1正2副角色数量校验（晋升/降级/换届时）
--   3. trg_join_apply_audit           入社申请审批联动（同意自动入社 + 消息通知）
--   4. trg_club_create_finalize       建团双审批结果联动（成功创建社团 / 驳回通知）
-- ============================================================
USE club_manage;

-- ------------------------------------------------------------
-- 1. 社团角色数量校验（新增社员时）
--    需求约束3：单个社团仅允许 1名正社长、最多2名副社长
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_club_member_role_insert;
DELIMITER $$
CREATE TRIGGER trg_club_member_role_insert
BEFORE INSERT ON club_member
FOR EACH ROW
BEGIN
    IF NEW.member_role = 'president' THEN
        IF EXISTS (SELECT 1 FROM club_member
                   WHERE club_id = NEW.club_id AND member_role = 'president'
                     AND leave_time IS NULL AND member_id <> NEW.member_id) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '该社团已存在在职正社长，不可重复设置';
        END IF;
    ELSEIF NEW.member_role = 'vice_president' THEN
        IF (SELECT COUNT(*) FROM club_member
            WHERE club_id = NEW.club_id AND member_role = 'vice_president'
              AND leave_time IS NULL AND member_id <> NEW.member_id) >= 2 THEN
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
BEFORE UPDATE ON club_member
FOR EACH ROW
BEGIN
    IF NEW.member_role <> OLD.member_role AND NEW.leave_time IS NULL THEN
        IF NEW.member_role = 'president' THEN
            IF EXISTS (SELECT 1 FROM club_member
                       WHERE club_id = NEW.club_id AND member_role = 'president'
                         AND leave_time IS NULL AND member_id <> NEW.member_id) THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '该社团已存在在职正社长，不可重复设置';
            END IF;
        ELSEIF NEW.member_role = 'vice_president' THEN
            IF (SELECT COUNT(*) FROM club_member
                WHERE club_id = NEW.club_id AND member_role = 'vice_president'
                  AND leave_time IS NULL AND member_id <> NEW.member_id) >= 2 THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '该社团在职副社长已达2名上限';
            END IF;
        END IF;
    END IF;
END$$
DELIMITER ;

-- ------------------------------------------------------------
-- 3. 入社申请审批联动触发器（需求5.2：学生入社闭环流程）
--    应用层仅需将 join_apply.apply_status 由 pending 更新为
--    agree/reject（同时更新 reply_time），本触发器自动完成：
--      agree  → 自动新增社员记录（默认普通社员）+ 推送入社成功通知
--      reject → 推送拒绝通知
--    若学生已在其他社团（uk_stu_active 唯一约束），同意操作将
--    被数据库唯一约束拦截并整体回滚，保证需求约束2不被破坏
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_join_apply_audit;
DELIMITER $$
CREATE TRIGGER trg_join_apply_audit
AFTER UPDATE ON join_apply
FOR EACH ROW
BEGIN
    DECLARE v_club_name VARCHAR(50);

    -- 仅处理 pending → agree/reject 的审批动作，避免重复触发
    IF OLD.apply_status = 'pending' AND NEW.apply_status IN ('agree', 'reject') THEN
        SELECT club_name INTO v_club_name FROM club WHERE club_id = NEW.club_id;

        IF NEW.apply_status = 'agree' THEN
            -- 同意：自动新增社员记录
            INSERT INTO club_member (club_id, stu_id, member_role)
            VALUES (NEW.club_id, NEW.stu_id, 'member');
            -- 推送入社成功通知
            INSERT INTO system_message (receiver_type, receiver_id, msg_title, msg_content, msg_type, biz_id)
            VALUES ('student', NEW.stu_id, '入社申请通过',
                    CONCAT('您申请加入【', v_club_name, '】的申请已通过，欢迎入社！'),
                    'join_apply', NEW.apply_id);
        ELSE
            -- 拒绝：推送拒绝通知
            INSERT INTO system_message (receiver_type, receiver_id, msg_title, msg_content, msg_type, biz_id)
            VALUES ('student', NEW.stu_id, '入社申请被拒绝',
                    CONCAT('您申请加入【', v_club_name, '】的申请未通过审批。'),
                    'join_apply', NEW.apply_id);
        END IF;
    END IF;
END$$
DELIMITER ;

-- ------------------------------------------------------------
-- 4. 建团双审批结果联动触发器（需求5.1：新社团创建闭环流程）
--    应用层在学生会/教师审批后计算并更新 final_status，
--    本触发器在 final_status 由 pending 变化时联动：
--      success → 创建社团 + 5名发起人自动入社（第1名正社长、
--                 第2-3名副社长、其余普通社员）+ 通知发起人与教师
--      fail    → 通知全部发起人
--    若社团名重复（uk_club_name）或教师已被绑定（uk_tea_id），
--    创建将被数据库唯一约束拦截并整体回滚
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_club_create_finalize;
DELIMITER $$
CREATE TRIGGER trg_club_create_finalize
AFTER UPDATE ON club_create_apply
FOR EACH ROW
BEGIN
    DECLARE v_club_id INT;
    DECLARE v_stu_id VARCHAR(20);
    DECLARE v_role VARCHAR(20);
    DECLARE v_rank INT DEFAULT 0;
    DECLARE v_done INT DEFAULT 0;
    DECLARE cur CURSOR FOR
        SELECT stu_id FROM club_create_apply_member
        WHERE create_apply_id = NEW.create_apply_id
        ORDER BY id;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    IF OLD.final_status = 'pending' AND NEW.final_status = 'success' THEN
        -- 双审批通过：创建社团
        INSERT INTO club (club_name, club_desc, club_create_time, tea_id)
        VALUES (NEW.club_name, NEW.club_desc, NOW(), NEW.apply_tea_id);
        SET v_club_id = LAST_INSERT_ID();

        -- 5名发起人自动入社：第1名正社长，第2-3名副社长，其余普通社员
        OPEN cur;
        member_loop: LOOP
            FETCH cur INTO v_stu_id;
            IF v_done = 1 THEN
                LEAVE member_loop;
            END IF;
            SET v_rank = v_rank + 1;
            SET v_role = CASE
                WHEN v_rank = 1 THEN 'president'
                WHEN v_rank <= 3 THEN 'vice_president'
                ELSE 'member'
            END;
            INSERT INTO club_member (club_id, stu_id, member_role)
            VALUES (v_club_id, v_stu_id, v_role);
        END LOOP;
        CLOSE cur;

        -- 通知全部发起人
        INSERT INTO system_message (receiver_type, receiver_id, msg_title, msg_content, msg_type, biz_id)
        SELECT 'student', stu_id, '建团申请通过',
               CONCAT('您参与发起的社团【', NEW.club_name, '】已创建成功！'),
               'club_create', v_club_id
        FROM club_create_apply_member
        WHERE create_apply_id = NEW.create_apply_id;
        -- 通知指导教师
        INSERT INTO system_message (receiver_type, receiver_id, msg_title, msg_content, msg_type, biz_id)
        VALUES ('teacher', NEW.apply_tea_id, '建团申请通过',
                CONCAT('您指导的新社团【', NEW.club_name, '】已创建成功！'),
                'club_create', v_club_id);

    ELSEIF OLD.final_status = 'pending' AND NEW.final_status = 'fail' THEN
        -- 任意一方驳回：通知全部发起人
        INSERT INTO system_message (receiver_type, receiver_id, msg_title, msg_content, msg_type, biz_id)
        SELECT 'student', stu_id, '建团申请未通过',
               CONCAT('您参与发起的社团【', NEW.club_name, '】建团申请未通过审批。'),
               'club_create', NEW.create_apply_id
        FROM club_create_apply_member
        WHERE create_apply_id = NEW.create_apply_id;
    END IF;
END$$
DELIMITER ;
