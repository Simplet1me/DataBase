package com.simplet1me.database.service;

import com.simplet1me.database.common.*;
import com.simplet1me.database.dto.Requests.*;
import com.simplet1me.database.mapper.Database;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Map;

/** 认证与密码比对；响应不包含密码哈希。 */
@Service
@Transactional
public class AuthService {
    private final Database db; private final JwtUtil jwt;
    public AuthService(Database db,JwtUtil jwt) { this.db=db; this.jwt=jwt; }
    public Map<String,Object> login(LoginReq req) {
        var row=db.one(req.userType(),"id",req.account());
        BizException.require(row!=null && equal(req.password().toLowerCase(),String.valueOf(row.get("password"))),1001,"账号或密码错误");
        var user=new UserContext.User(req.account(),row.get("name").toString(),req.userType());
        var result=profile(user); result.put("token",jwt.create(user)); return result;
    }
    private boolean equal(String a,String b) { return MessageDigest.isEqual(a.getBytes(StandardCharsets.UTF_8),b.getBytes(StandardCharsets.UTF_8)); }
    public Map<String,Object> profile() { return profile(UserContext.get()); }
    private Map<String,Object> profile(UserContext.User user) {
        var row=db.one(user.userType(),"id",user.id());
        BizException.require(row!=null,401,"账号不存在，请重新登录");
        boolean student="student".equals(user.userType());
        var club=student?db.one("activeMember","stuId",user.id()):null;
        return Database.args("id",user.id(),"name",row.get("name"),"userType",user.userType(),
            "unionMember",student && db.one("unionMember","stuId",user.id())!=null,
            "club",club==null?null:Database.args("clubId",club.get("clubId"),"clubName",club.get("clubName"),"clubRole",club.get("memberRole")));
    }
    public Map<String,Object> personal() {
        var user=UserContext.get(); BizException.require("student".equals(user.userType()),403,"仅学生可查看");
        var row=db.need("student","id",user.id()); row.remove("password"); return row;
    }
    public void password(PasswordReq req) {
        db.writeLock(); var user=UserContext.get(); var row=db.need(user.userType(),"id",user.id());
        BizException.require(equal(req.oldPassword().toLowerCase(),row.get("password").toString()),1001,"原密码错误");
        db.update("student".equals(user.userType())?"studentPassword":"teacherPassword","id",user.id(),"password",req.newPassword().toLowerCase());
    }
}
