package com.simplet1me.database.common;

import com.auth0.jwt.JWT;
import com.auth0.jwt.algorithms.Algorithm;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import java.time.Instant;

/** 令牌只保存基础身份，社团和学生会权限不写入令牌。 */
@Component
public class JwtUtil {
    private final Algorithm algorithm;
    private final long hours;
    public JwtUtil(@Value("${app.jwt.secret}") String secret, @Value("${app.jwt.hours}") long hours) {
        this.algorithm = Algorithm.HMAC256(secret); this.hours = hours;
    }
    public String create(UserContext.User user) {
        return JWT.create().withIssuer("club-manage").withSubject(user.id())
            .withClaim("id", user.id()).withClaim("name", user.name()).withClaim("userType", user.userType())
            .withIssuedAt(Instant.now()).withExpiresAt(Instant.now().plusSeconds(hours * 3600)).sign(algorithm);
    }
    public UserContext.User parse(String token) {
        try {
            var jwt = JWT.require(algorithm).withIssuer("club-manage").build().verify(token);
            String type = jwt.getClaim("userType").asString();
            if (!"student".equals(type) && !"teacher".equals(type)) throw new IllegalArgumentException();
            return new UserContext.User(jwt.getSubject(), jwt.getClaim("name").asString(), type);
        } catch (Exception e) { throw new BizException(401, "登录已失效，请重新登录"); }
    }
}
