-- ============================================================
-- 存储过程脚本（need.md 考核内容3：存储过程等数据库对象的编写）
-- 数据库：club_manage
--
-- 存储过程清单：
--   1. sp_submit_join_apply       提交入社申请（约束2单社团/约束9防重复/约束12解散冻结）
--   2. sp_change_member_role      社员角色变更（晋升/降级/社长换届 + 变更日志）
--   3. sp_submit_dissolve_apply   提交社团解散申请（仅社长/A3同一社团仅一条待审批）
--   4. sp_create_club             建团双审批通过执行（A2：原触发器联动改为后端调用）
--   5. sp_dissolve_club           社团解散执行（双审批通过后调用，事务删除）
--
-- 说明：入社审批联动由触发器 trg_join_apply_audit 完成（应用层仅更新
--       状态字段）；建团审批通过的联动不再使用触发器，由后端在事务中
--       显式调用 sp_create_club 完成（评审决策 A2）。
-- ============================================================
USE club_manage;

-- ------------------------------------------------------------
-- 1. 提交入社申请（需求4.1.3 / 约束2 / 约束9 / 约束12）
--    校验：① 未加入任何社团（约束2：学生单社团）
--          ② 无任何待审批入社申请（约束9：同一学生同时只能有一个
--             在途申请，不可同时向多个社团提交，评审决策 A1）
--          ③ 目标社团无待审批解散申请（约束12：解散期间暂停入社）
--    校验通过后写入 join_apply，审批结果由触发器联动
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_submit_join_apply;
DELIMITER $$
CREATE PROCEDURE sp_submit_join_apply(
    IN p_club_id INT,
    IN p_stu_id VARCHAR(20)
)
BEGIN
    -- 约束2：学生不可同时加入多个社团
    IF EXISTS (SELECT 1
               FROM club_member
               WHERE stu_id = p_stu_id
                 AND leave_time IS NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '您已加入社团，不可再提交入社申请';
    END IF;
    -- 约束9（评审决策 A1）：同一学生同时只能有一个待审批入社申请
    IF EXISTS (SELECT 1
               FROM join_apply
               WHERE stu_id = p_stu_id
                 AND apply_status = 'pending') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '您已有待审批的入社申请，请等待审批结果后再提交';
    END IF;
    -- 约束12（评审决策 B2）：目标社团解散申请待审批期间暂停入社
    IF EXISTS (SELECT 1
               FROM club_dissolve_apply
               WHERE club_id = p_club_id
                 AND final_status = 'pending') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '该社团正在解散审批中，暂停入社申请';
    END IF;
    INSERT INTO join_apply (club_id, stu_id)
    VALUES (p_club_id, p_stu_id);
END$$
DELIMITER ;

-- ------------------------------------------------------------
-- 2. 社员角色变更：晋升/降级/社长换届（需求4.2.2）
--    更新角色时由触发器 trg_club_member_role_update 自动校验
--    1正2副数量约束；变更成功后写入角色变更日志永久追溯。
--    换届操作顺序（评审决策 B5）：必须先将原社长及需调整的
--    副社长降级为普通社员，再晋升新社长（先升会被触发器拦截）。
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
    SELECT member_role
    INTO v_old_role
    FROM club_member
    WHERE club_id = p_club_id
      AND stu_id = p_stu_id
      AND leave_time IS NULL;
    IF v_old_role IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '目标学生不是本社团在职社员';
    END IF;

    -- 操作人必须是本社团在职管理层（正/副社长，评审决策 B4 平权）
    SELECT member_role
    INTO v_op_role
    FROM club_member
    WHERE club_id = p_club_id
      AND stu_id = p_operate_stu_id
      AND leave_time IS NULL;
    IF v_op_role IS NULL OR v_op_role NOT IN ('president', 'vice_president') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '操作人无社员权限管理权限';
    END IF;

    IF v_old_role <> p_new_role THEN
        -- 更新角色（触发器负责 1正2副 数量校验，违规即回滚）
        UPDATE club_member
        SET member_role = p_new_role
        WHERE club_id = p_club_id
          AND stu_id = p_stu_id
          AND leave_time IS NULL;
        -- 写入角色变更日志（永久追溯）
        INSERT INTO club_member_change_log
            (club_id, stu_id, old_role, new_role, operate_stu_id)
        VALUES (p_club_id, p_stu_id, v_old_role, p_new_role, p_operate_stu_id);
    END IF;
END$$
DELIMITER ;

-- ------------------------------------------------------------
-- 3. 提交社团解散申请（需求4.2.6 / 评审决策 A3）
--    校验：① 发起人须为该社团在职社长（仅社长可发起解散）
--          ② 同一社团同一时间只能存在一条待审批解散申请
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_submit_dissolve_apply;
DELIMITER $$
CREATE PROCEDURE sp_submit_dissolve_apply(
    IN p_club_id INT,
    IN p_stu_id VARCHAR(20)
)
BEGIN
    DECLARE v_role VARCHAR(20);

    -- 仅社团社长可发起解散申请
    SELECT member_role
    INTO v_role
    FROM club_member
    WHERE club_id = p_club_id
      AND stu_id = p_stu_id
      AND leave_time IS NULL;
    IF v_role IS NULL OR v_role <> 'president' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '仅社团社长可发起解散申请';
    END IF;

    -- 评审决策 A3：同一社团同一时间只能存在一条待审批解散申请
    IF EXISTS (SELECT 1
               FROM club_dissolve_apply
               WHERE club_id = p_club_id
                 AND final_status = 'pending') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '该社团已有待审批的解散申请，不可重复发起';
    END IF;

    INSERT INTO club_dissolve_apply (club_id, apply_stu_id)
    VALUES (p_club_id, p_stu_id);
END$$
DELIMITER ;

-- ------------------------------------------------------------
-- 4. 建团双审批通过执行（需求5.1 / 评审决策 A2：触发器联动改为后端调用）
--    由后端在学生会与教师双审批都通过后显式调用。
--    事务内：校验发起人均无社团归属（uk_stu_active 兜底）→ 创建社团
--    → 5名发起人入社（第1名正社长、第2-3名副社长、其余普通社员）
--    → 置 final_status='success'。
--    任一发起人已入他社 / 社名重复（uk_club_name）/ 教师已被绑定
--    （uk_tea_id）时整体回滚，后端捕获错误提示具体原因。
--    驳回时后端直接置 final_status='fail'，无需调用本过程。
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_create_club;
DELIMITER $$
CREATE PROCEDURE sp_create_club(
    IN p_create_apply_id INT
)
BEGIN
    DECLARE v_club_id INT;
    DECLARE v_club_name VARCHAR(50);
    DECLARE v_club_desc TEXT;
    DECLARE v_tea_id VARCHAR(20);
    DECLARE v_union_status VARCHAR(20);
    DECLARE v_tea_status VARCHAR(20);
    DECLARE v_final_status VARCHAR(20);
    DECLARE v_stu_id VARCHAR(20);
    DECLARE v_role VARCHAR(20);
    DECLARE v_rank INT DEFAULT 0;
    DECLARE v_done INT DEFAULT 0;
    DECLARE cur CURSOR FOR
        SELECT stu_id
        FROM club_create_apply_member
        WHERE create_apply_id = p_create_apply_id
        ORDER BY id;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            RESIGNAL;
        END;

    SELECT club_name,
           club_desc,
           apply_tea_id,
           union_audit_status,
           tea_audit_status,
           final_status
    INTO v_club_name, v_club_desc, v_tea_id,
        v_union_status, v_tea_status, v_final_status
    FROM club_create_apply
    WHERE create_apply_id = p_create_apply_id;
    IF v_club_name IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '建团申请不存在';
    END IF;
    -- 双审批必须都已通过
    IF v_union_status <> 'agree' OR v_tea_status <> 'agree' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '建团申请双审批未全部通过，不可创建社团';
    END IF;
    IF v_final_status <> 'pending' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '该建团申请已处理，不可重复执行';
    END IF;

    START TRANSACTION;
    -- 创建社团（uk_club_name / uk_tea_id 冲突时整体回滚）
    INSERT INTO club (club_name, club_desc, club_create_time, tea_id)
    VALUES (v_club_name, v_club_desc, NOW(), v_tea_id);
    SET v_club_id = LAST_INSERT_ID();

    -- 5名发起人入社（uk_stu_active 冲突时整体回滚）
    OPEN cur;
    member_loop:
    LOOP
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

    -- 置最终状态（无触发器联动，状态更新由本过程显式控制）
    UPDATE club_create_apply
    SET final_status = 'success'
    WHERE create_apply_id = p_create_apply_id;
    COMMIT;
END$$
DELIMITER ;

-- ------------------------------------------------------------
-- 5. 社团解散执行（需求5.5：社团解散闭环流程）
--    由后端在解散申请双审批通过（final_status='success'）后调用。
--    事务内按外键依赖顺序删除（全部外键为 RESTRICT，无级联可用）：
--      入社申请 → 活动 → 公告 → 角色变更日志 → 社员 → 解散申请 → 社团
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
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            RESIGNAL;
        END;

    -- 校验解散申请已双审批通过
    SELECT club_id
    INTO v_club_id
    FROM club_dissolve_apply
    WHERE dissolve_apply_id = p_dissolve_apply_id
      AND final_status = 'success';
    IF v_club_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '解散申请不存在或未通过双审批';
    END IF;

    START TRANSACTION;
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
