package com.simplet1me.database.common;

import jakarta.validation.ConstraintViolationException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.resource.NoResourceFoundException;
import java.sql.SQLException;

/** 数据库 SIGNAL 原文透传，数据库内部错误只写日志。 */
@RestControllerAdvice
public class GlobalExceptionHandler {
    private static final Logger LOG = LoggerFactory.getLogger(GlobalExceptionHandler.class);
    @ExceptionHandler(BizException.class)
    public Result<Void> business(BizException e) { return Result.error(e.code, e.getMessage()); }
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public Result<Void> validation(MethodArgumentNotValidException e) {
        return Result.error(400, e.getBindingResult().getAllErrors().get(0).getDefaultMessage());
    }
    @ExceptionHandler({HttpMessageNotReadableException.class, MethodArgumentTypeMismatchException.class, ConstraintViolationException.class})
    public Result<Void> badRequest(Exception e) { return Result.error(400, "请求参数格式错误"); }
    @ExceptionHandler(NoResourceFoundException.class)
    public Result<Void> missing(Exception e) { return Result.error(404, "资源不存在"); }
    @ExceptionHandler(Exception.class)
    public Result<Void> failure(Exception e) {
        for (Throwable cause = e; cause != null; cause = cause.getCause()) {
            if (cause instanceof SQLException sql) {
                if ("45000".equals(sql.getSQLState())) return Result.error(1001, sql.getMessage());
                if (sql.getErrorCode() == 1062) return Result.error(1002, "数据冲突，请刷新后重试");
            }
        }
        if (e instanceof DuplicateKeyException) return Result.error(1002, "数据冲突，请刷新后重试");
        LOG.error("请求处理失败", e);
        return Result.error(500, "服务器错误，请稍后重试");
    }
}
