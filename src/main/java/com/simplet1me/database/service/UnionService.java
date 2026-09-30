package com.simplet1me.database.service;

import com.simplet1me.database.common.*;
import com.simplet1me.database.dto.Requests.*;
import com.simplet1me.database.mapper.Database;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.*;
import java.util.Map;

/** 学生会平权管理与公告式系统消息。 */
@Service
@Transactional(isolation=Isolation.READ_COMMITTED)
public class UnionService {
    private final Database db; private final AccessService access;
    public UnionService(Database db,AccessService access) { this.db=db; this.access=access; }
    public Object members() { access.union(); return db.list("unionMembers"); }
    public Object logs() { access.union(); return db.list("unionLogs"); }
    public void add(UnionMemberReq req) {
        db.writeLock(); access.union(); db.need("student","id",req.stuId());
        db.insert("addUnion","stuId",req.stuId()); db.insert("unionLog","stuId",req.stuId(),"type","add","operator",access.id());
    }
    public void remove(String stuId) {
        db.writeLock(); access.union(); db.need("unionMember","stuId",stuId);
        BizException.require(db.list("unionMembers").size()>1,1001,"学生会至少保留一名成员");
        db.update("removeUnion","stuId",stuId); db.insert("unionLog","stuId",stuId,"type","remove","operator",access.id());
    }
    public Object messages() { return db.list("messages"); }
    public Object message(Long id,MessageReq req) {
        db.writeLock(); access.union();
        if(id==null) return Map.of("msgId",db.insert("addMessage","title",req.msgTitle(),"content",req.msgContent(),"operator",access.id()));
        db.changed(db.update("editMessage","id",id,"title",req.msgTitle(),"content",req.msgContent())); return null;
    }
    public void deleteMessage(long id) { db.writeLock(); access.union(); db.changed(db.update("deleteMessage","id",id)); }
}
