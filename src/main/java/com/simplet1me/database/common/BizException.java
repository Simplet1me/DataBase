package com.simplet1me.database.common;

/** 可向用户展示的业务异常。 */
public class BizException extends RuntimeException {
    public final int code;
    public BizException(String message) { this(1001, message); }
    public BizException(int code, String message) { super(message); this.code = code; }
    public static void require(boolean condition, int code, String message) {
        if (!condition) throw new BizException(code, message);
    }
}
