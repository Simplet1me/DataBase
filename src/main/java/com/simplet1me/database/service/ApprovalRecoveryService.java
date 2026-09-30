package com.simplet1me.database.service;

import org.mybatis.spring.SqlSessionTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.*;
import java.util.Map;

/** 原过程 START TRANSACTION 会隐式提交审批更新；失败后用独立事务恢复审批前快照。 */
@Service
public class ApprovalRecoveryService {
    private final SqlSessionTemplate session;
    public ApprovalRecoveryService(SqlSessionTemplate session) { this.session=session; }
    @Transactional(propagation=Propagation.REQUIRES_NEW)
    public void restore(boolean create,Map<String,Object> snapshot) {
        session.update(create?"db.restoreCreate":"db.restoreDissolve",snapshot);
    }
}
