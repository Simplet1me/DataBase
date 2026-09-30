package com.simplet1me.database.service;

import com.simplet1me.database.common.*;
import com.simplet1me.database.dto.Requests.*;
import com.simplet1me.database.mapper.Database;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.*;
import java.util.*;

/** 建团与解散双审批，任意一方驳回立即结束；第二个同意触发原过程。 */
@Service
@Transactional(isolation=Isolation.READ_COMMITTED)
public class ApprovalService {
    private final Database db; private final AccessService access; private final ApprovalRecoveryService recovery;
    public ApprovalService(Database db,AccessService access,ApprovalRecoveryService recovery) { this.db=db; this.access=access; this.recovery=recovery; }
    public Object creates(String scope) {
        if("union".equals(scope)||"history".equals(scope)) access.union();
        else if("teacher".equals(scope)) access.teacher(); else access.student();
        var rows=db.list("creates","scope",scope,"userId",access.id());
        rows.forEach(r->r.put("initiators",db.list("initiators","id",r.get("createApplyId")))); return rows;
    }
    public Object dissolves(boolean teacher) {
        if(teacher) access.teacher(); else access.union();
        return db.list("dissolves","scope",teacher?"teacher":"union","userId",access.id());
    }
    public void audit(long id,AuditReq req,boolean create,boolean teacher) {
        db.writeLock(); var before=db.one(create?"create":"dissolve","id",id);
        if(before==null) throw new BizException(404,"该申请已被处理");
        if(teacher) access.teacherOf(before.get(create?"applyTeaId":"teaId")); else access.union();
        String statement=teacher?(create?"teacherAuditCreate":"teacherAuditDissolve"):(create?"unionAuditCreate":"unionAuditDissolve");
        db.changed(db.update(statement,"id",id,"result",req.result(),"operator",access.id(),"finalStatus","reject".equals(req.result())?"fail":"pending"));
        var updated=db.need(create?"create":"dissolve","id",id);
        if("agree".equals(updated.get("unionAuditStatus")) && "agree".equals(updated.get("teaAuditStatus"))) {
            try {
                if(!create) db.changed(db.update("dissolveSuccess","id",id));
                db.call(create?"spCreate":"spDissolve","id",id);
            } catch(RuntimeException failure) {
                // 过程内部回滚不涵盖其隐式提交之前的审批字段，需要显式恢复。
                recovery.restore(create,before); throw failure;
            }
        }
    }
    public Object teacherClub() {
        access.teacher(); var club=db.one("clubByTeacher","teaId",access.id()); if(club==null) return null;
        Object id=club.get("clubId"); club.put("members",db.list("members","clubId",id));
        club.put("activities",db.list("allActivities","clubId",id));
        club.put("notices",db.list("notices","clubId",id,"all",false)); return club;
    }
    public Object teacherActivities() { access.teacher(); return db.list("teacherActivities","teaId",access.id()); }
    public void activity(long id,AuditReq req) {
        db.writeLock(); var row=db.need("activity","id",id); access.teacherOf(row.get("teaId"));
        db.changed(db.update("auditActivity","id",id,"teaId",access.id(),"status","agree".equals(req.result())?"running":"reject"));
    }
}
