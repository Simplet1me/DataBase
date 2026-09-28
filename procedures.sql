-- ============================================================
-- 存储过程脚本（need.md 考核内容3：存储过程等数据库对象的编写）
-- 数据库：club_manage
--
-- 存储过程清单：
--   1. sp_submit_join_apply   提交入社申请（约束2单社团 + 约束9防重复校验）
--   2. sp_change_member_role  社员角色变更（晋升/降级/社长换届 + 变更日志）
--   3. sp_dissolve_club       社团解散执行（双审批通过后调用，事务删除）
--
-- 说明：入社审批联动（trg_join_apply_audit）、建团审批联动
--       （trg_club_create_finalize）由触发器完成，应用层仅更新
--       状态字段即可，无需重复实现业务联动。
-- ============================================================
USE club_manage;

-- ------------------------------------------------------------
-- 1. 提交入社申请（需求4.1.3 / 约束2 / 约束9）
--    校验通过后写入 join_apply，审批结果由触发器联动推送
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_submit_join_apply;
DELIMITER $$
CREATE PROCEDURE sp_submit_join_apply(
    IN p_club_id INT,
    IN p_stu_id VARCHAR(20)
)
BEGIN
    -- 约束2：学生不可同时加入多个社团
    IF EXISTS (SELECT 1 FROM club_member
               WHERE stu_id = p_stu_id AND leave_time IS NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '您已加入社团，不可再提交入社申请';
    END IF;
    -- 约束9：同一社团不可重复提交待审批申请
    IF EXISTS (SELECT 1 FROM join_apply
               WHERE club_id = p_club_id AND stu_id = p_stu_id
                 AND apply_status = 'pending') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '您已向该社团提交过待审批申请，请勿重复提交';
    END IF;
    INSERT INTO join_apply (club_id, stu_id)
    VALUES (p_club_id, p_stu_id);
END$$
DELIMITER ;

-- ------------------------------------------------------------
-- 2. 社员角色变更：晋升/降级/社长换届（需求4.2.2）
--    更新角色时由触发器 trg_club_member_role_update 自动校验
--    1正2副数量约束；变更成功后写入角色变更日志永久追溯
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_change_member_role;
DELIMITER $$
CREATE PROCEDURE sp_change_member_role(
    IN p_club_id INT,
    IN p_stu_id VARCHAR(20),
    IN p_new_role VARCHAR(20),
    IN p_operate_stu_id VARCHAR(20)
)
BEGIN
    DECLARE v_old_role VARCHAR(20);
    DECLARE v_op_role VARCHAR(20);

    -- 目标学生必须为本社团在职社员
    SELECT member_role INTO v_old_role
    FROM club_member
    WHERE club_id = p_club_id AND stu_id = p_stu_id AND leave_time IS NULL;
    IF v_old_role IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '目标学生不是本社团在职社员';
    END IF;

    -- 操作人必须是本社团在职管理层（正/副社长）
    SELECT member_role INTO v_op_role
    FROM club_member
    WHERE club_id = p_club_id AND stu_id = p_operate_stu_id AND leave_time IS NULL;
    IF v_op_role NOT IN ('president', 'vice_president') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '操作人无社员权限管理权限';
    END IF;

    IF v_old_role <> p_new_role THEN
        -- 更新角色（触发器负责 1正2副 数量校验，违规即回滚）
        UPDATE club_member
        SET member_role = p_new_role
        WHERE club_id = p_club_id AND stu_id = p_stu_id AND leave_time IS NULL;
        -- 写入角色变更日志（永久追溯）
        INSERT INTO club_member_change_log
            (club_id, stu_id, old_role, new_role, operate_stu_id)
        VALUES (p_club_id, p_stu_id, v_old_role, p_new_role, p_operate_stu_id);
    END IF;
END$$
DELIMITER ;

-- ------------------------------------------------------------
-- 3. 社团解散执行（需求5.5：社团解散闭环流程）
--    由应用层在解散申请双审批通过（final_status='success'）后调用。
--    事务内按外键依赖顺序删除（全部外键为 RESTRICT，无级联可用）：
--      入社申请 → 活动 → 公告 → 角色变更日志 → 社员 → 解散申请 → 社团
--    删除前先向在职社员与指导教师推送解散通知（消息保留在个人列表）。
--    删除后：社员恢复无社团归属、管理层职位释放、指导教师恢复空闲
--    （uk_tea_id / uk_club_name 唯一约束随社团删除自动释放）。
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_dissolve_club;
DELIMITER $$
CREATE PROCEDURE sp_dissolve_club(
    IN p_dissolve_apply_id INT
)
BEGIN
    DECLARE v_club_id INT;
    DECLARE v_club_name VARCHAR(50);
    DECLARE v_tea_id VARCHAR(20);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- 校验解散申请已双审批通过
    SELECT club_id INTO v_club_id
    FROM club_dissolve_apply
    WHERE dissolve_apply_id = p_dissolve_apply_id AND final_status = 'success';
    IF v_club_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '解散申请不存在或未通过双审批';
    END IF;

    SELECT club_name, tea_id INTO v_club_name, v_tea_id
    FROM club WHERE club_id = v_club_id;

    START TRANSACTION;
        -- 通知在职社员（消息保留，biz_id 为松散引用不随删除失效）
        INSERT INTO system_message (receiver_type, receiver_id, msg_title, msg_content, msg_type, biz_id)
        SELECT 'student', stu_id, '社团解散通知',
               CONCAT('您所在的社团【', v_club_name, '】已正式解散。'),
               'club_dissolve', v_club_id
        FROM club_member
        WHERE club_id = v_club_id AND leave_time IS NULL;
        -- 通知指导教师
        IF v_tea_id IS NOT NULL THEN
            INSERT INTO system_message (receiver_type, receiver_id, msg_title, msg_content, msg_type, biz_id)
            VALUES ('teacher', v_tea_id, '社团解散通知',
                    CONCAT('您指导的社团【', v_club_name, '】已正式解散。'),
                    'club_dissolve', v_club_id);
        END IF;

        -- 按外键依赖顺序删除（RESTRICT 外键下必须遵守此顺序）
        DELETE FROM join_apply WHERE club_id = v_club_id;
        DELETE FROM club_activity WHERE club_id = v_club_id;
        DELETE FROM club_notice WHERE club_id = v_club_id;
        DELETE FROM club_member_change_log WHERE club_id = v_club_id;
        DELETE FROM club_member WHERE club_id = v_club_id;
        DELETE FROM club_dissolve_apply WHERE club_id = v_club_id;
        DELETE FROM club WHERE club_id = v_club_id;
    COMMIT;
END$$
DELIMITER ;
