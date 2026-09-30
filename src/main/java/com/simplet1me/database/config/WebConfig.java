package com.simplet1me.database.config;

import com.simplet1me.database.common.*;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.context.annotation.Configuration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.config.annotation.*;

/** 拦截器仅处理登录态，权限校验全部在业务层。 */
@Configuration
public class WebConfig implements WebMvcConfigurer {
    private final JwtUtil jwt;
    private final String[] origins;
    public WebConfig(JwtUtil jwt, @Value("${app.cors.origins}") String[] origins) { this.jwt = jwt; this.origins = origins; }
    @Override public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(new HandlerInterceptor() {
            @Override public boolean preHandle(HttpServletRequest req, HttpServletResponse res, Object handler) {
                UserContext.clear();
                if ("OPTIONS".equals(req.getMethod())) return true;
                String header = req.getHeader("Authorization");
                if (header == null || !header.startsWith("Bearer ")) throw new BizException(401, "请先登录");
                UserContext.set(jwt.parse(header.substring(7))); return true;
            }
            @Override public void afterCompletion(HttpServletRequest req, HttpServletResponse res, Object h, Exception ex) {
                UserContext.clear();
            }
        }).addPathPatterns("/api/**").excludePathPatterns("/api/auth/login");
    }
    @Override public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**").allowedOrigins(origins)
            .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS").allowedHeaders("*");
    }
}
