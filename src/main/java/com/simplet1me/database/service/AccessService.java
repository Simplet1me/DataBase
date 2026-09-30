package com.simplet1me.database.service;

import com.simplet1me.database.common.*;
import com.simplet1me.database.mapper.Database;
import org.springframework.stereotype.Service;
import java.util.Map;

/** 每次业务调用实时读取身份，兼任身份按权限并集处理。 */
@Service
public class AccessService {
    private final Database db;
    public AccessService(Database db) { this.db=db; }
    public String id() { return UserContext.get().id(); }
    public void student() { BizException.require("student".equals(UserContext.get().userType()),403,"仅学生可操作"); }
    public void teacher() { BizException.require("teacher".equals(UserContext.get().userType()),403,"仅教师可操作"); }
    public void union() { student(); BizException.require(db.one("unionMember","stuId",id())!=null,403,"仅学生会成员可操作"); }
    public Map<String,Object> member(long clubId) {
        student(); var row=db.one("member","clubId",clubId,"stuId",id());
        BizException.require(row!=null,403,"仅本社团在职社员可操作"); return row;
    }
    public Map<String,Object> manager(long clubId) {
        var row=member(clubId);
        BizException.require(!"member".equals(row.get("memberRole")),403,"仅本社团管理层可操作"); return row;
    }
    public void president(long clubId) { BizException.require("president".equals(manager(clubId).get("memberRole")),403,"仅社长可发起换届"); }
    public void teacherOf(Object teacherId) { teacher(); BizException.require(id().equals(teacherId),403,"仅所属指导教师可操作"); }
}
