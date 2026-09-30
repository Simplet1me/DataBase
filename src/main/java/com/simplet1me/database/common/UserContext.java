package com.simplet1me.database.common;

/** 请求结束必须清理线程上下文，复合权限始终从数据库重新获取。 */
public final class UserContext {
    public record User(String id, String name, String userType) {}
    private static final ThreadLocal<User> CURRENT = new ThreadLocal<>();
    public static User get() {
        if (CURRENT.get() == null) throw new BizException(401, "请先登录");
        return CURRENT.get();
    }
    public static void set(User user) { CURRENT.set(user); }
    public static void clear() { CURRENT.remove(); }
}
