package com.simplet1me.database.dto;

import jakarta.validation.constraints.*;
import java.util.List;

/** 请求字段与接口文档保持一致，字符串在进入数据库前校验长度。 */
public final class Requests {
    public record LoginReq(@NotNull @Pattern(regexp="student|teacher", message="请选择学生或教师") String userType,
        @NotBlank @Size(max=20) String account, @NotBlank @Pattern(regexp="[0-9a-fA-F]{64}", message="密码必须为 SHA-256 哈希") String password) {}
    public record AuditReq(@NotNull @Pattern(regexp="agree|reject", message="审批结果必须为 agree 或 reject") String result) {}
    public record RoleReq(@NotBlank @Size(max=20) String stuId,
        @NotNull @Pattern(regexp="president|vice_president|member", message="角色不合法") String newRole) {}
    public record PresidentReq(@NotNull @Size(max=3) List<@NotBlank @Size(max=20) String> demoteStuIds,
        @NotBlank @Size(max=20) String newPresidentStuId) {}
    public record CreateReq(@NotBlank @Size(max=50) String clubName, @NotBlank @Size(max=10000) String clubDesc,
        @NotBlank @Size(max=20) String applyTeaId, @NotNull @Size(min=5,max=5,message="必须恰好有5名发起人") List<@NotBlank @Size(max=20) String> stuIds) {}
    public record ActivityReq(@NotBlank @Size(max=50) String actName, @NotBlank @Size(max=10000) String actDesc,
        @NotBlank String actStartTime, @NotBlank String actEndTime, @NotBlank @Size(max=100) String actPlace) {}
    public record NoticeReq(@NotBlank @Size(max=100) String noticeTitle, @NotBlank @Size(max=10000) String noticeContent) {}
    public record MessageReq(@NotBlank @Size(max=100) String msgTitle, @NotBlank @Size(max=10000) String msgContent) {}
    public record UnionMemberReq(@NotBlank @Size(max=20) String stuId) {}
    public record PasswordReq(@NotNull @Pattern(regexp="[0-9a-fA-F]{64}") String oldPassword,
        @NotNull @Pattern(regexp="[0-9a-fA-F]{64}") String newPassword) {}
}
