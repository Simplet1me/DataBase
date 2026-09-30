package com.simplet1me.database.controller;

import com.simplet1me.database.common.Result;
import com.simplet1me.database.dto.Requests.*;
import com.simplet1me.database.service.*;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

/** 控制器只接收参数并调用业务层，不在此处计算权限。 */
@RestController
@RequestMapping("/api")
public class ApiController {
    private final AuthService auth; private final ClubService club; private final ApprovalService approval; private final UnionService union;
    public ApiController(AuthService auth,ClubService club,ApprovalService approval,UnionService union) { this.auth=auth; this.club=club; this.approval=approval; this.union=union; }
    @PostMapping("/auth/login") public Result<?> login(@Valid @RequestBody LoginReq r) { return Result.ok(auth.login(r)); }
    @GetMapping("/auth/profile") public Result<?> profile() { return Result.ok(auth.profile()); }
    @GetMapping("/auth/personal") public Result<?> personal() { return Result.ok(auth.personal()); }
    @PutMapping("/auth/password") public Result<?> password(@Valid @RequestBody PasswordReq r) { auth.password(r); return Result.ok(null); }
    @GetMapping("/clubs") public Result<?> clubs() { return Result.ok(club.clubs()); }
    @GetMapping("/clubs/my") public Result<?> myClub() { return Result.ok(club.myClub()); }
    @GetMapping("/clubs/{clubId}") public Result<?> detail(@PathVariable long clubId) { return Result.ok(club.detail(clubId)); }
    @PostMapping("/clubs/{clubId}/join-applies") public Result<?> join(@PathVariable long clubId) { return Result.ok(club.join(clubId)); }
    @GetMapping("/join-applies/my") public Result<?> myJoins() { return Result.ok(club.myJoins()); }
    @GetMapping("/members/my") public Result<?> myRecords() { return Result.ok(club.myRecords()); }
    @GetMapping("/members/my/role-logs") public Result<?> myRoleLogs() { return Result.ok(club.myRoleLogs()); }
    @PostMapping("/members/my/quit") public Result<?> quit() { return Result.ok(club.quit()); }
    @GetMapping("/clubs/{clubId}/members") public Result<?> members(@PathVariable long clubId) { return Result.ok(club.members(clubId)); }
    @GetMapping("/clubs/{clubId}/members/history") public Result<?> memberHistory(@PathVariable long clubId) { return Result.ok(club.memberHistory(clubId)); }
    @PostMapping("/clubs/{clubId}/members/{stuId}/kick") public Result<?> kick(@PathVariable long clubId,@PathVariable String stuId) { club.kick(clubId,stuId); return Result.ok(null); }
    @PostMapping("/clubs/{clubId}/role-change") public Result<?> role(@PathVariable long clubId,@Valid @RequestBody RoleReq r) { return Result.ok(club.role(clubId,r)); }
    @PostMapping("/clubs/{clubId}/change-president") public Result<?> president(@PathVariable long clubId,@Valid @RequestBody PresidentReq r) { return Result.ok(club.president(clubId,r)); }
    @GetMapping("/clubs/{clubId}/join-applies") public Result<?> pendingJoins(@PathVariable long clubId) { return Result.ok(club.pendingJoins(clubId)); }
    @PostMapping("/join-applies/{id}/audit") public Result<?> auditJoin(@PathVariable long id,@Valid @RequestBody AuditReq r) { club.auditJoin(id,r); return Result.ok(null); }
    @GetMapping("/clubs/{clubId}/activities") public Result<?> activities(@PathVariable long clubId) { return Result.ok(club.activities(clubId,false)); }
    @GetMapping("/clubs/{clubId}/activities/all") public Result<?> allActivities(@PathVariable long clubId) { return Result.ok(club.activities(clubId,true)); }
    @PostMapping("/clubs/{clubId}/activities") public Result<?> activity(@PathVariable long clubId,@Valid @RequestBody ActivityReq r) { return Result.ok(club.addActivity(clubId,r)); }
    @PostMapping("/clubs/{clubId}/activities/{id}/finish") public Result<?> finish(@PathVariable long clubId,@PathVariable long id) { club.finish(clubId,id); return Result.ok(null); }
    @GetMapping("/clubs/{clubId}/notices") public Result<?> notices(@PathVariable long clubId) { return Result.ok(club.notices(clubId)); }
    @PostMapping("/clubs/{clubId}/notices") public Result<?> addNotice(@PathVariable long clubId,@Valid @RequestBody NoticeReq r) { return Result.ok(club.notice(clubId,null,r)); }
    @PutMapping("/clubs/{clubId}/notices/{id}") public Result<?> editNotice(@PathVariable long clubId,@PathVariable long id,@Valid @RequestBody NoticeReq r) { return Result.ok(club.notice(clubId,id,r)); }
    @DeleteMapping("/clubs/{clubId}/notices/{id}") public Result<?> deleteNotice(@PathVariable long clubId,@PathVariable long id) { club.deleteNotice(clubId,id); return Result.ok(null); }
    @PostMapping("/clubs/{clubId}/dissolve-applies") public Result<?> submitDissolve(@PathVariable long clubId) { return Result.ok(club.submitDissolve(clubId)); }
    @GetMapping("/clubs/{clubId}/dissolve-applies") public Result<?> clubDissolves(@PathVariable long clubId) { return Result.ok(club.dissolves(clubId)); }
    @GetMapping("/teachers/free") public Result<?> freeTeachers() { return Result.ok(club.freeTeachers()); }
    @PostMapping("/create-applies") public Result<?> submitCreate(@Valid @RequestBody CreateReq r) { return Result.ok(club.submitCreate(r)); }
    @GetMapping("/create-applies/my") public Result<?> myCreates() { return Result.ok(approval.creates("my")); }
    @GetMapping("/messages") public Result<?> messages() { return Result.ok(union.messages()); }
    @PostMapping("/messages") public Result<?> addMessage(@Valid @RequestBody MessageReq r) { return Result.ok(union.message(null,r)); }
    @PutMapping("/messages/{id}") public Result<?> editMessage(@PathVariable long id,@Valid @RequestBody MessageReq r) { return Result.ok(union.message(id,r)); }
    @DeleteMapping("/messages/{id}") public Result<?> deleteMessage(@PathVariable long id) { union.deleteMessage(id); return Result.ok(null); }
    @GetMapping("/union/members") public Result<?> unionMembers() { return Result.ok(union.members()); }
    @GetMapping("/union/member-logs") public Result<?> unionLogs() { return Result.ok(union.logs()); }
    @PostMapping("/union/members") public Result<?> addUnion(@Valid @RequestBody UnionMemberReq r) { union.add(r); return Result.ok(null); }
    @DeleteMapping("/union/members/{stuId}") public Result<?> removeUnion(@PathVariable String stuId) { union.remove(stuId); return Result.ok(null); }
    @GetMapping("/union/create-applies") public Result<?> unionCreates() { return Result.ok(approval.creates("union")); }
    @GetMapping("/union/audit-records") public Result<?> auditRecords() { return Result.ok(approval.creates("history")); }
    @PostMapping("/union/create-applies/{id}/audit") public Result<?> unionCreate(@PathVariable long id,@Valid @RequestBody AuditReq r) { approval.audit(id,r,true,false); return Result.ok(null); }
    @GetMapping("/union/dissolve-applies") public Result<?> unionDissolves() { return Result.ok(approval.dissolves(false)); }
    @PostMapping("/union/dissolve-applies/{id}/audit") public Result<?> unionDissolve(@PathVariable long id,@Valid @RequestBody AuditReq r) { approval.audit(id,r,false,false); return Result.ok(null); }
    @GetMapping("/teacher/create-applies") public Result<?> teacherCreates() { return Result.ok(approval.creates("teacher")); }
    @PostMapping("/teacher/create-applies/{id}/audit") public Result<?> teacherCreate(@PathVariable long id,@Valid @RequestBody AuditReq r) { approval.audit(id,r,true,true); return Result.ok(null); }
    @GetMapping("/teacher/dissolve-applies") public Result<?> teacherDissolves() { return Result.ok(approval.dissolves(true)); }
    @PostMapping("/teacher/dissolve-applies/{id}/audit") public Result<?> teacherDissolve(@PathVariable long id,@Valid @RequestBody AuditReq r) { approval.audit(id,r,false,true); return Result.ok(null); }
    @GetMapping("/teacher/club") public Result<?> teacherClub() { return Result.ok(approval.teacherClub()); }
    @GetMapping("/teacher/activities") public Result<?> teacherActivities() { return Result.ok(approval.teacherActivities()); }
    @PostMapping("/teacher/activities/{id}/audit") public Result<?> auditActivity(@PathVariable long id,@Valid @RequestBody AuditReq r) { approval.activity(id,r); return Result.ok(null); }
}
