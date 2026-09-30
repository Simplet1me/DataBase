// 共享表格字段与接口文档保持一致。
export const memberColumns = [{ key: 'stuName', label: '姓名' }, { key: 'stuId', label: '学号' }, { key: 'stuClass', label: '班级' }, { key: 'stuPhone', label: '联系方式' }, { key: 'memberRole', label: '角色', status: true }, { key: 'joinTime', label: '入社时间', width: 180 }]
export const joinColumns = [{ key: 'stuName', label: '申请人' }, { key: 'stuId', label: '学号' }, { key: 'stuClass', label: '班级' }, { key: 'stuPhone', label: '联系方式' }, { key: 'applyTime', label: '申请时间', width: 180 }]
export const activityColumns = [{ key: 'actName', label: '活动名称', width: 160 }, { key: 'actPlace', label: '地点' }, { key: 'actStartTime', label: '开始时间', width: 180 }, { key: 'actEndTime', label: '结束时间', width: 180 }, { key: 'actStatus', label: '状态', status: true }, { key: 'auditTeaName', label: '审批教师' }, { key: 'auditTime', label: '审批时间', width: 180 }]
export const noticeFields = [{ key: 'noticeTitle', label: '公告标题', max: 100 }, { key: 'noticeContent', label: '公告内容', type: 'textarea', max: 10000 }]
export const messageFields = [{ key: 'msgTitle', label: '消息标题', max: 100 }, { key: 'msgContent', label: '消息内容', type: 'textarea', max: 10000 }]
