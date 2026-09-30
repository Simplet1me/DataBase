package com.simplet1me.database.common;

/** 所有接口使用同一响应结构，业务错误码独立于传输状态。 */
public record Result<T>(int code, String message, T data) {
    public static <T> Result<T> ok(T data) { return new Result<>(0, "success", data); }
    public static Result<Void> error(int code, String message) { return new Result<>(code, message, null); }
}
