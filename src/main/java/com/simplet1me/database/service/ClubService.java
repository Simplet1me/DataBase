package com.simplet1me.database.service;

import com.simplet1me.database.common.*;
import com.simplet1me.database.dto.Requests.*;
import com.simplet1me.database.mapper.Database;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.*;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.time.format.ResolverStyle;
import java.util.*;

/** 学生及社团管理层业务，入社联动完全由数据库触发器负责。 */
@Service
@Transactional(isolation=Isolation.READ_COMMITTED)
public class ClubService {
    private final Database db; private final AccessService access;
    public ClubService(Database db,AccessService access) { this.db=db; this.access=access; }
    public Object clubs() { return db.list("clubs"); }
    public Map<String,Object> detail(long id) {
        var club=db.need("club","clubId",id); club.put("notices",db.list("notices","clubId",id,"all",false)); return club;
    }
    public Object myClub() {
        access.student(); var m=db.one("activeMember","stuId",access.id());
        BizException.require(m!=null,403,"您当前没有管理的社团");
        long id=((Number)m.get("clubId")).longValue(); access.manager(id); return db.need("club","clubId",id);
    }
    public Object join(long clubId) {
        db.writeLock(); access.student(); db.need("club","clubId",clubId);
        db.call("spJoin","clubId",clubId,"stuId",access.id()); return Map.of("applyId",db.lastId());
    }
    public Object myJoins() { access.student(); return db.list("myJoins","stuId",access.id()); }
    public Object myRecords() { access.student(); return db.list("myRecords","stuId",access.id()); }
    public Object myRoleLogs() { access.student(); return db.list("myRoleLogs","stuId",access.id()); }
    public Object memberHistory(long clubId) { access.manager(clubId); return db.list("memberHistory","clubId",clubId); }
    public Object quit() {
        db.writeLock(); access.student(); var row=db.need("activeMember","stuId",access.id());
        db.update("quit","stuId",access.id()); return db.need("leftMember","id",row.get("memberId"));
    }
    public Object members(long clubId) { access.manager(clubId); return db.list("members","clubId",clubId); }
    public void kick(long clubId,String stuId) {
        db.writeLock(); access.manager(clubId); var row=db.need("member","clubId",clubId,"stuId",stuId);
        BizException.require(!"president".equals(row.get("memberRole")),1001,"社长不可被踢出");
        db.changed(db.update("kick","clubId",clubId,"stuId",stuId,"operator",access.id()));
    }
    public Object role(long clubId,RoleReq req) {
        db.writeLock(); access.manager(clubId); var old=db.one("member","clubId",clubId,"stuId",req.stuId());
        // 先调用原存储过程，数量冲突及非社员提示保持原文；不允许单人接口绕过换届。
        db.call("spRole","clubId",clubId,"stuId",req.stuId(),"role",req.newRole(),"operator",access.id());
        BizException.require(!"president".equals(req.newRole()) && !"president".equals(old.get("memberRole")),1001,"社长变更请使用换届接口");
        return Map.of("oldRole",old.get("memberRole"),"newRole",req.newRole());
    }
    public Object president(long clubId,PresidentReq req) {
        db.writeLock(); access.president(clubId);
        BizException.require(new HashSet<>(req.demoteStuIds()).size()==req.demoteStuIds().size(),400,"降级名单不能重复");
        BizException.require(!req.newPresidentStuId().equals(access.id()),400,"请选择其他在职社员作为新社长");
        var target=db.one("member","clubId",clubId,"stuId",req.newPresidentStuId());
        if(target==null) {
            db.call("spRole","clubId",clubId,"stuId",req.newPresidentStuId(),"role","president","operator",access.id());
            throw new BizException("目标学生不是本社团在职社员");
        }
        List<Map<String,Object>> changes=new ArrayList<>();
        long before=((Number)db.need("maxRoleLog","clubId",clubId).get("id")).longValue();
        Long bridgeLog=null; String bridgeStudent=null; String bridgeOriginal=null;
        Set<String> remainingDemotions=new HashSet<>(req.demoteStuIds());
        // 原过程逐次检查操作人角色，现任社长降级后由事务内仍在职的副社长承接调用。
        for(String stuId:req.demoteStuIds()) {
            remainingDemotions.remove(stuId);
            var old=db.one("member","clubId",clubId,"stuId",stuId);
            BizException.require(old!=null,1001,"目标学生不是本社团在职社员");
            BizException.require(!"member".equals(old.get("memberRole")),400,"降级名单只能包含管理层");
            var all=db.list("members","clubId",clubId);
            long managers=all.stream().filter(m->!"member".equals(m.get("memberRole"))).count();
            // 没有保留副社长时，临时赋予另一社员副社长角色以跨过过程权限检查，事务外不可见。
            if(managers==1) {
                String candidate=all.stream().map(m->m.get("stuId").toString())
                    .filter(s->!s.equals(stuId) && !remainingDemotions.contains(s)).findFirst().orElse(null);
                if(candidate==null) candidate=req.newPresidentStuId();
                BizException.require(!candidate.equals(stuId),400,"换届需另一名在职社员");
                bridgeStudent=candidate; bridgeOriginal=db.need("member","clubId",clubId,"stuId",candidate).get("memberRole").toString();
                db.call("spRole","clubId",clubId,"stuId",candidate,"role","vice_president","operator",operator(clubId));
                bridgeLog=((Number)db.need("maxRoleLog","clubId",clubId).get("id")).longValue();
            }
            db.call("spRole","clubId",clubId,"stuId",stuId,"role","member","operator",operator(clubId));
            changes.add(Database.args("stuId",stuId,"oldRole",old.get("memberRole"),"newRole","member"));
        }
        String targetOld=req.demoteStuIds().contains(req.newPresidentStuId())?"member":target.get("memberRole").toString();
        db.call("spRole","clubId",clubId,"stuId",req.newPresidentStuId(),"role","president","operator",operator(clubId));
        changes.add(Database.args("stuId",req.newPresidentStuId(),"oldRole",targetOld,"newRole","president"));
        if(bridgeLog!=null) {
            if(bridgeStudent.equals(req.newPresidentStuId())) {
                db.update("bridgeOldRole","clubId",clubId,"stuId",bridgeStudent,"role",targetOld,"afterId",before);
            } else {
                db.call("spRole","clubId",clubId,"stuId",bridgeStudent,"role",bridgeOriginal,"operator",req.newPresidentStuId());
                long restoreLog=((Number)db.need("maxRoleLog","clubId",clubId).get("id")).longValue();
                db.update("removeBridgeLog","id",restoreLog);
            }
            // 仅清理本事务临时桥接产生的日志，正式变更统一记录实际请求人。
            db.update("removeBridgeLog","id",bridgeLog);
        }
        db.update("roleLogOperator","clubId",clubId,"afterId",before,"operator",access.id());
        return Map.of("changes",changes);
    }
    private String operator(long clubId) {
        return db.list("members","clubId",clubId).stream().filter(m->!"member".equals(m.get("memberRole")))
            .map(m->m.get("stuId").toString()).findFirst().orElseThrow(()->new BizException("无可执行换届的管理层"));
    }
    public Object pendingJoins(long clubId) { access.manager(clubId); return db.list("pendingJoins","clubId",clubId); }
    public void auditJoin(long id,AuditReq req) {
        db.writeLock(); var row=db.need("join","id",id); access.manager(((Number)row.get("clubId")).longValue());
        try { db.changed(db.update("auditJoin","id",id,"result",req.result(),"operator",access.id())); }
        catch(DuplicateKeyException e) { throw new BizException(1002,"该学生已加入其他社团，审批已回滚"); }
    }
    public Object activities(long clubId,boolean all) {
        if(all) access.manager(clubId); else access.member(clubId);
        return db.list(all?"allActivities":"activities","clubId",clubId);
    }
    public Object addActivity(long clubId,ActivityReq req) {
        db.writeLock(); access.manager(clubId);
        BizException.require(db.one("pendingDissolve","clubId",clubId)==null,1001,"该社团正在解散审批中");
        try {
            var format=DateTimeFormatter.ofPattern("uuuu-MM-dd HH:mm:ss").withResolverStyle(ResolverStyle.STRICT);
            var start=LocalDateTime.parse(req.actStartTime(),format); var end=LocalDateTime.parse(req.actEndTime(),format);
            BizException.require(end.isAfter(start),400,"结束时间必须晚于开始时间");
        } catch(java.time.format.DateTimeParseException e) { throw new BizException(400,"时间格式必须为 yyyy-MM-dd HH:mm:ss"); }
        long id=db.insert("addActivity","clubId",clubId,"name",req.actName(),"desc",req.actDesc(),"start",req.actStartTime(),"end",req.actEndTime(),"place",req.actPlace());
        return Map.of("actId",id);
    }
    public void finish(long clubId,long id) {
        db.writeLock(); access.manager(clubId); db.changed(db.update("finishActivity","clubId",clubId,"id",id));
    }
    public Object notices(long clubId) { access.manager(clubId); return db.list("notices","clubId",clubId,"all",true); }
    public Object notice(long clubId,Long id,NoticeReq req) {
        db.writeLock(); access.manager(clubId);
        if(id==null) return Map.of("noticeId",db.insert("addNotice","clubId",clubId,"title",req.noticeTitle(),"content",req.noticeContent(),"operator",access.id()));
        db.changed(db.update("editNotice","clubId",clubId,"id",id,"title",req.noticeTitle(),"content",req.noticeContent())); return null;
    }
    public void deleteNotice(long clubId,long id) {
        db.writeLock(); access.manager(clubId); db.changed(db.update("deleteNotice","clubId",clubId,"id",id));
    }
    public Object submitDissolve(long clubId) {
        db.writeLock(); access.manager(clubId);
        // 副社长被原过程拒绝，保持接口约定的 1001 与 SIGNAL 原文。
        db.call("spSubmitDissolve","clubId",clubId,"stuId",access.id()); return Map.of("dissolveApplyId",db.lastId());
    }
    public Object dissolves(long clubId) { access.manager(clubId); return db.list("dissolves","scope","club","clubId",clubId); }
    public Object freeTeachers() { access.student(); return db.list("freeTeachers"); }
    public Object submitCreate(CreateReq req) {
        db.writeLock(); access.student();
        BizException.require(new HashSet<>(req.stuIds()).size()==5,400,"发起人必须为5名不同学生");
        BizException.require(req.stuIds().get(0).equals(access.id()),400,"第一名发起人必须为当前学生");
        for(String stuId:req.stuIds()) {
            BizException.require(db.one("student","id",stuId)!=null,1001,"发起人学号不存在："+stuId);
            BizException.require(db.one("activeMember","stuId",stuId)==null,1001,"发起人已有社团："+stuId);
        }
        db.need("teacher","id",req.applyTeaId());
        BizException.require(db.one("clubByTeacher","teaId",req.applyTeaId())==null,1002,"该教师已绑定社团");
        BizException.require(db.one("clubByName","name",req.clubName())==null,1002,"社团名称已存在");
        long id=db.insert("addCreate","name",req.clubName(),"desc",req.clubDesc(),"teaId",req.applyTeaId());
        for(String stuId:req.stuIds()) db.insert("addInitiator","id",id,"stuId",stuId);
        return Map.of("createApplyId",id);
    }
}
