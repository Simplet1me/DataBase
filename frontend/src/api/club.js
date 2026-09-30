import request from '../utils/request'
export const clubApi = {
  list: () => request.get('/clubs'), detail: id => request.get(`/clubs/${id}`), mine: () => request.get('/clubs/my'),
  join: id => request.post(`/clubs/${id}/join-applies`), myJoins: () => request.get('/join-applies/my'),
  records: () => request.get('/members/my'), logs: () => request.get('/members/my/role-logs'), quit: () => request.post('/members/my/quit'),
  freeTeachers: () => request.get('/teachers/free'), create: data => request.post('/create-applies', data), creates: () => request.get('/create-applies/my'),
  members: id => request.get(`/clubs/${id}/members`), history: id => request.get(`/clubs/${id}/members/history`),
  kick: (id, stuId) => request.post(`/clubs/${id}/members/${stuId}/kick`), role: (id, data) => request.post(`/clubs/${id}/role-change`, data),
  president: (id, data) => request.post(`/clubs/${id}/change-president`, data),
  joins: id => request.get(`/clubs/${id}/join-applies`), auditJoin: (id, result) => request.post(`/join-applies/${id}/audit`, { result }),
  activities: (id, all = false) => request.get(`/clubs/${id}/activities${all ? '/all' : ''}`),
  activity: (id, data) => request.post(`/clubs/${id}/activities`, data), finish: (id, actId) => request.post(`/clubs/${id}/activities/${actId}/finish`),
  notices: id => request.get(`/clubs/${id}/notices`),
  notice: (id, data, noticeId) => noticeId ? request.put(`/clubs/${id}/notices/${noticeId}`, data) : request.post(`/clubs/${id}/notices`, data),
  deleteNotice: (id, noticeId) => request.delete(`/clubs/${id}/notices/${noticeId}`),
  dissolves: id => request.get(`/clubs/${id}/dissolve-applies`), dissolve: id => request.post(`/clubs/${id}/dissolve-applies`),
}
