package com.simplet1me.database.mapper;

import com.simplet1me.database.common.BizException;
import org.mybatis.spring.SqlSessionTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import java.sql.*;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

/** 固定语句标识对应 XML，用户输入只通过绑定参数传递。 */
@Repository
public class Database {
    private final SqlSessionTemplate session;
    private static final DateTimeFormatter TIME = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    public Database(SqlSessionTemplate session) { this.session = session; }
    public static Map<String,Object> args(Object... pairs) {
        Map<String,Object> map = new LinkedHashMap<>();
        for (int i=0; i<pairs.length; i+=2) map.put((String)pairs[i], pairs[i+1]);
        return map;
    }
    private Map<String,Object> normalize(Map<String,Object> row) {
        Map<String,Object> result = new LinkedHashMap<>();
        row.forEach((key,value) -> {
            StringBuilder camel = new StringBuilder(); boolean upper = false;
            for (char c : key.toCharArray()) { if (c=='_') { upper=true; continue; } camel.append(upper?Character.toUpperCase(c):c); upper=false; }
            if (value instanceof Timestamp t) value = t.toLocalDateTime().format(TIME);
            if (value instanceof LocalDateTime t) value = t.format(TIME);
            result.put(camel.toString(),value);
        });
        return result;
    }
    public List<Map<String,Object>> list(String id, Object... pairs) {
        List<Map<String,Object>> rows = session.selectList("db."+id,args(pairs));
        return rows.stream().map(this::normalize).toList();
    }
    public Map<String,Object> one(String id, Object... pairs) {
        var rows=list(id,pairs); return rows.isEmpty()?null:rows.get(0);
    }
    public Map<String,Object> need(String id, Object... pairs) {
        var row=one(id,pairs); if(row==null) throw new BizException(404,"资源不存在"); return row;
    }
    public int update(String id,Object... pairs) { return session.update("db."+id,args(pairs)); }
    public long insert(String id,Object... pairs) {
        session.insert("db."+id,args(pairs)); return lastId();
    }
    public long lastId() { return ((Number)one("lastId").get("id")).longValue(); }
    public void call(String id,Object... pairs) { session.selectList("db."+id,args(pairs)); }
    public void changed(int n) { if(n==0) throw new BizException(404,"该申请已被处理"); }
    /** 课程系统写请求使用数据库命名锁，覆盖存储过程内部提交及多实例并发。 */
    public void writeLock() {
        if (!TransactionSynchronizationManager.isActualTransactionActive()) throw new IllegalStateException("写操作必须处于事务中");
        String name = String.valueOf(need("databaseName").get("name"))+":business";
        if (!Integer.valueOf(1).equals(((Number)need("getLock","name",name).get("locked")).intValue()))
            throw new BizException(1001,"系统繁忙，请稍后重试");
        Connection connection=session.getConnection();
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override public void afterCompletion(int status) {
                try (var statement=connection.prepareStatement("SELECT RELEASE_LOCK(?)")) {
                    statement.setString(1,name); statement.execute();
                } catch (SQLException e) { throw new IllegalStateException("释放业务锁失败",e); }
            }
        });
    }
}
