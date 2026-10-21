package com.simplet1me.database;

import com.simplet1me.database.common.BizException;
import com.simplet1me.database.common.UserContext;
import com.simplet1me.database.mapper.Database;
import com.simplet1me.database.service.AccessService;
import com.simplet1me.database.service.ClubService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import java.util.List;
import java.util.Map;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** 使用真实权限服务验证社员只读边界，不依赖或修改演示数据库。 */
class MemberReadAccessTests {
    private Database db;
    private ClubService service;

    @BeforeEach void prepare() {
        db = mock(Database.class);
        service = new ClubService(db, new AccessService(db));
        UserContext.set(new UserContext.User("2021009", "测试社员", "student"));
        when(db.one("member", "clubId", 1L, "stuId", "2021009"))
            .thenReturn(Map.of("memberRole", "member"));
    }
    @AfterEach void clear() { UserContext.clear(); }

    @Test void memberCanReadAllActivityStatesAndOnlyActiveNotices() {
        var activities = List.<Map<String,Object>>of(Map.of("actStatus", "wait_audit"));
        var notices = List.<Map<String,Object>>of(Map.of("noticeTitle", "有效公告"));
        when(db.list("allActivities", "clubId", 1L)).thenReturn(activities);
        when(db.list("notices", "clubId", 1L, "all", false)).thenReturn(notices);
        assertEquals(activities, service.activities(1L, true));
        assertEquals(notices, service.notices(1L));
    }

    @Test void outsidersCannotReadClubInformation() {
        when(db.one("member", "clubId", 2L, "stuId", "2021009")).thenReturn(null);
        assertThrows(BizException.class, () -> service.activities(2L, true));
        assertThrows(BizException.class, () -> service.notices(2L));
        verify(db, never()).list("allActivities", "clubId", 2L);
        verify(db, never()).list("notices", "clubId", 2L, "all", false);
    }

    @Test void memberCannotManageActivitiesOrNotices() {
        assertThrows(BizException.class, () -> service.addActivity(1L, null));
        assertThrows(BizException.class, () -> service.finish(1L, 1L));
        assertThrows(BizException.class, () -> service.notice(1L, null, null));
        assertThrows(BizException.class, () -> service.notice(1L, 1L, null));
        assertThrows(BizException.class, () -> service.deleteNotice(1L, 1L));
    }

    @Test void managerRetainsDeletedNoticeVisibility() {
        when(db.one("member", "clubId", 1L, "stuId", "2021009"))
            .thenReturn(Map.of("memberRole", "president"));
        var notices = List.<Map<String,Object>>of(Map.of("isDeleted", 1));
        when(db.list("notices", "clubId", 1L, "all", true)).thenReturn(notices);
        assertEquals(notices, service.notices(1L));
    }
}
