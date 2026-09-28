-- 创建数据库
CREATE DATABASE IF NOT EXISTS club_manage DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE club_manage;

-- 1.学生表 student
DROP TABLE IF EXISTS student;
CREATE TABLE student (
    stu_id VARCHAR(20) PRIMARY KEY COMMENT '学生学号',
    stu_name VARCHAR(20) NOT NULL COMMENT '学生姓名',
    stu_gender CHAR(2) COMMENT '性别 男/女',
    stu_class VARCHAR(30) COMMENT '班级',
    stu_phone VARCHAR(11) COMMENT '联系电话',
    stu_pwd VARCHAR(64) COMMENT '登录密码(SHA256哈希值)'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='学生信息表';

-- 2.教师表 teacher
DROP TABLE IF EXISTS teacher;
CREATE TABLE teacher (
    tea_id VARCHAR(20) PRIMARY KEY COMMENT '教师工号',
    tea_name VARCHAR(20) NOT NULL COMMENT '教师姓名',
    tea_phone VARCHAR(11) COMMENT '联系电话',
    tea_pwd VARCHAR(64) COMMENT '登录密码(SHA256哈希值)'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='教师信息表';

-- 3.学生会管理部门成员表(仅保存当前有效成员)
DROP TABLE IF EXISTS student_union_member;
CREATE TABLE student_union_member (
    id INT AUTO_INCREMENT PRIMARY KEY COMMENT '主键',
    stu_id VARCHAR(20) NOT NULL COMMENT '学生会成员学号',
    join_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '加入时间',
    UNIQUE KEY uk_stu_id (stu_id),
    FOREIGN KEY (stu_id) REFERENCES student(stu_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='学生会当前成员表';

-- 3‑1 学生会成员操作日志表【新增优化】
DROP TABLE IF EXISTS student_union_operate_log;
CREATE TABLE student_union_operate_log (
    log_id INT AUTO_INCREMENT PRIMARY KEY COMMENT '日志id',
    stu_id VARCHAR(20) NOT NULL COMMENT '操作对象学号',
    operate_type VARCHAR(20) NOT NULL COMMENT '操作类型 add/remove',
    operate_stu_id VARCHAR(20) NOT NULL COMMENT '操作人学号',
    operate_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '操作时间',
    FOREIGN KEY (stu_id) REFERENCES student(stu_id) ON DELETE RESTRICT,
    FOREIGN KEY (operate_stu_id) REFERENCES student(stu_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='学生会成员变动日志';

-- 4.社团表 club
DROP TABLE IF EXISTS club;
CREATE TABLE club (
    club_id INT AUTO_INCREMENT PRIMARY KEY COMMENT '社团编号',
    club_name VARCHAR(50) NOT NULL COMMENT '社团名称',
    club_desc TEXT COMMENT '社团简介',
    club_create_time DATETIME COMMENT '社团正式创建时间',
    tea_id VARCHAR(20) COMMENT '指导教师工号',
    UNIQUE KEY uk_club_name (club_name),
    UNIQUE KEY uk_tea_id (tea_id) COMMENT '一个教师只能指导一个社团',
    FOREIGN KEY (tea_id) REFERENCES teacher(tea_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='社团信息表';

-- 5.社团社员表 club_member
DROP TABLE IF EXISTS club_member;
CREATE TABLE club_member (
    member_id INT AUTO_INCREMENT PRIMARY KEY COMMENT '社员id',
    club_id INT NOT NULL COMMENT '社团id',
    stu_id VARCHAR(20) NOT NULL COMMENT '学生学号',
    member_role VARCHAR(20) NOT NULL COMMENT '角色 president正社长 vice_president副社长 member普通社员',
    join_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '入社时间',
    leave_time DATETIME NULL COMMENT '退社时间 NULL代表仍在社团',
    leave_type VARCHAR(20) NULL COMMENT '退社类型 kick踢出 quit主动退社',
    operate_stu_id VARCHAR(20) NULL COMMENT '退社操作人学号 踢出为管理层学号 主动退社为学生本人学号',
    -- 生成列：在社为1 已退社为NULL（NULL不参与唯一性比较） 配合唯一索引保证在社记录唯一
    is_active TINYINT GENERATED ALWAYS AS (CASE WHEN leave_time IS NULL THEN 1 ELSE NULL END) STORED COMMENT '在社标记生成列',
    -- 联合唯一：同一个学生同一社团只能有一条在社记录
    UNIQUE KEY uk_club_stu (club_id, stu_id, is_active),
    -- 学生单社团归属：同一个学生全库只能有一条在社记录
    UNIQUE KEY uk_stu_active (stu_id, is_active),
    FOREIGN KEY (club_id) REFERENCES club(club_id) ON DELETE RESTRICT,
    FOREIGN KEY (stu_id) REFERENCES student(stu_id) ON DELETE RESTRICT,
    FOREIGN KEY (operate_stu_id) REFERENCES student(stu_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='社团社员表';

-- 6.社员角色变更日志 club_member_change_log
DROP TABLE IF EXISTS club_member_change_log;
CREATE TABLE club_member_change_log (
    log_id INT AUTO_INCREMENT PRIMARY KEY COMMENT '日志id',
    club_id INT NOT NULL COMMENT '社团id',
    stu_id VARCHAR(20) NOT NULL COMMENT '变更学生学号',
    old_role VARCHAR(20) COMMENT '变更前角色',
    new_role VARCHAR(20) COMMENT '变更后角色',
    operate_stu_id VARCHAR(20) NOT NULL COMMENT '操作人学号',
    change_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '变更时间',
    FOREIGN KEY (club_id) REFERENCES club(club_id) ON DELETE RESTRICT,
    FOREIGN KEY (stu_id) REFERENCES student(stu_id) ON DELETE RESTRICT,
    FOREIGN KEY (operate_stu_id) REFERENCES student(stu_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='社员角色变更日志';

-- 7.入社申请表 join_apply
DROP TABLE IF EXISTS join_apply;
CREATE TABLE join_apply (
    apply_id INT AUTO_INCREMENT PRIMARY KEY COMMENT '申请编号',
    club_id INT NOT NULL COMMENT '申请社团id',
    stu_id VARCHAR(20) NOT NULL COMMENT '申请学生学号',
    apply_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '提交申请时间',
    apply_status VARCHAR(20) NOT NULL DEFAULT 'pending' COMMENT 'pending待审批 agree同意 reject拒绝',
    reply_time DATETIME NULL COMMENT '审批回复时间',
    KEY idx_club_status (club_id, apply_status),
    FOREIGN KEY (club_id) REFERENCES club(club_id) ON DELETE RESTRICT,
    FOREIGN KEY (stu_id) REFERENCES student(stu_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='入社申请表';

-- 8.社团创建申请表 club_create_apply
DROP TABLE IF EXISTS club_create_apply;
CREATE TABLE club_create_apply (
    create_apply_id INT AUTO_INCREMENT PRIMARY KEY COMMENT '申请id',
    club_name VARCHAR(50) NOT NULL COMMENT '拟创建社团名称',
    club_desc TEXT COMMENT '社团简介',
    apply_tea_id VARCHAR(20) NOT NULL COMMENT '申请指定指导教师',
    apply_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '提交申请时间',
    union_audit_status VARCHAR(20) NOT NULL DEFAULT 'pending' COMMENT '学生会审批 pending agree reject',
    union_audit_stu_id VARCHAR(20) COMMENT '学生会审批人学号',
    union_audit_time DATETIME NULL COMMENT '学生会审批时间',
    tea_audit_status VARCHAR(20) NOT NULL DEFAULT 'pending' COMMENT '教师审批 pending agree reject',
    tea_audit_time DATETIME NULL COMMENT '教师审批时间',
    final_status VARCHAR(20) NOT NULL DEFAULT 'pending' COMMENT '最终状态 pending待双审 success全部通过 fail任一驳回',
    FOREIGN KEY (apply_tea_id) REFERENCES teacher(tea_id) ON DELETE RESTRICT,
    FOREIGN KEY (union_audit_stu_id) REFERENCES student(stu_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='社团创建申请表';

-- 8‑1 社团创建申请发起人表
DROP TABLE IF EXISTS club_create_apply_member;
CREATE TABLE club_create_apply_member (
    id INT AUTO_INCREMENT PRIMARY KEY COMMENT '主键',
    create_apply_id INT NOT NULL COMMENT '创建申请id',
    stu_id VARCHAR(20) NOT NULL COMMENT '发起人学号',
    FOREIGN KEY (create_apply_id) REFERENCES club_create_apply(create_apply_id) ON DELETE RESTRICT,
    FOREIGN KEY (stu_id) REFERENCES student(stu_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='社团创建申请发起人';

-- 9.社团解散申请表 club_dissolve_apply
DROP TABLE IF EXISTS club_dissolve_apply;
CREATE TABLE club_dissolve_apply (
    dissolve_apply_id INT AUTO_INCREMENT PRIMARY KEY COMMENT '解散申请id',
    club_id INT NOT NULL COMMENT '待解散社团id',
    apply_stu_id VARCHAR(20) NOT NULL COMMENT '提交申请学生学号',
    apply_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '提交时间',
    union_audit_status VARCHAR(20) NOT NULL DEFAULT 'pending' COMMENT '学生会审批 pending agree reject',
    union_audit_stu_id VARCHAR(20) COMMENT '学生会审批人学号',
    union_audit_time DATETIME NULL COMMENT '学生会审批时间',
    tea_audit_status VARCHAR(20) NOT NULL DEFAULT 'pending' COMMENT '教师审批 pending agree reject',
    tea_audit_time DATETIME NULL COMMENT '教师审批时间',
    final_status VARCHAR(20) NOT NULL DEFAULT 'pending' COMMENT '最终状态 pending success fail',
    FOREIGN KEY (club_id) REFERENCES club(club_id) ON DELETE RESTRICT,
    FOREIGN KEY (apply_stu_id) REFERENCES student(stu_id) ON DELETE RESTRICT,
    FOREIGN KEY (union_audit_stu_id) REFERENCES student(stu_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='社团解散申请表';

-- 10.社团活动表 club_activity
DROP TABLE IF EXISTS club_activity;
CREATE TABLE club_activity (
    act_id INT AUTO_INCREMENT PRIMARY KEY COMMENT '活动编号',
    club_id INT NOT NULL COMMENT '所属社团id',
    act_name VARCHAR(50) NOT NULL COMMENT '活动名称',
    act_desc TEXT COMMENT '活动介绍',
    act_start_time DATETIME COMMENT '活动开始时间',
    act_end_time DATETIME COMMENT '活动结束时间',
    act_place VARCHAR(100) COMMENT '活动地点',
    apply_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '提交申办时间',
    act_status VARCHAR(20) NOT NULL DEFAULT 'wait_audit' COMMENT 'wait_audit待审批 running进行中 finish已结束 reject驳回',
    audit_tea_id VARCHAR(20) COMMENT '审批教师工号',
    audit_time DATETIME NULL COMMENT '审批时间',
    KEY idx_club_act_status (club_id, act_status),
    FOREIGN KEY (club_id) REFERENCES club(club_id) ON DELETE RESTRICT,
    FOREIGN KEY (audit_tea_id) REFERENCES teacher(tea_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='社团活动表';

-- 11.社团公告表 club_notice
DROP TABLE IF EXISTS club_notice;
CREATE TABLE club_notice (
    notice_id INT AUTO_INCREMENT PRIMARY KEY COMMENT '公告id',
    club_id INT NOT NULL COMMENT '社团id',
    notice_title VARCHAR(100) NOT NULL COMMENT '公告标题',
    notice_content TEXT COMMENT '公告内容',
    publish_stu_id VARCHAR(20) NOT NULL COMMENT '发布人学号',
    publish_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '发布时间',
    FOREIGN KEY (club_id) REFERENCES club(club_id) ON DELETE RESTRICT,
    FOREIGN KEY (publish_stu_id) REFERENCES student(stu_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='社团公告表';

-- 12.系统消息通知表 system_message【优化：增加biz_id业务id】
DROP TABLE IF EXISTS system_message;
CREATE TABLE system_message (
    msg_id INT AUTO_INCREMENT PRIMARY KEY COMMENT '消息id',
    receiver_type VARCHAR(20) NOT NULL COMMENT '接收者类型 student/teacher',
    receiver_id VARCHAR(20) NOT NULL COMMENT '接收人id(学号/工号)',
    msg_title VARCHAR(100) NOT NULL COMMENT '消息标题',
    msg_content TEXT COMMENT '消息内容',
    msg_type VARCHAR(30) NOT NULL COMMENT '消息类型 join_apply club_create club_dissolve activity_audit',
    biz_id INT NULL COMMENT '关联业务主键id',
    is_read TINYINT NOT NULL DEFAULT 0 COMMENT '0未读 1已读',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '消息生成时间',
    KEY idx_receiver_read (receiver_type, receiver_id, is_read)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='系统消息通知表';
