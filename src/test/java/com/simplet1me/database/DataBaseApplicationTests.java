package com.simplet1me.database;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.http.MediaType;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties={"spring.datasource.url=jdbc:mysql://localhost:3306/club_manage_test?useUnicode=true&characterEncoding=UTF-8&serverTimezone=Asia/Shanghai"})
@AutoConfigureMockMvc
class DataBaseApplicationTests {
    @Autowired MockMvc mvc;

    @Test
    void contextLoads() {
    }

    /** 未登录请求使用统一响应，拦截器不接受伪造令牌。 */
    @Test void authenticationRequired() throws Exception {
        mvc.perform(get("/api/clubs")).andExpect(jsonPath("$.code").value(401));
        mvc.perform(get("/api/clubs").header("Authorization","Bearer invalid")).andExpect(jsonPath("$.code").value(401));
    }
    /** 请求校验失败不进入数据库流程。 */
    @Test void invalidLoginBody() throws Exception {
        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content("{}"))
            .andExpect(jsonPath("$.code").value(400));
    }
    /** 演示学生登录后返回复合身份与令牌。 */
    @Test void studentLogin() throws Exception {
        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content("""
            {"userType":"student","account":"2021006","password":"8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92"}
            """))
            .andExpect(jsonPath("$.code").value(0)).andExpect(jsonPath("$.data.unionMember").value(true))
            .andExpect(jsonPath("$.data.club.clubRole").value("president")).andExpect(jsonPath("$.data.token").isString());
    }

}
