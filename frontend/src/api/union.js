import request from '../utils/request'
export const unionApi = {
  creates: () => request.get('/union/create-applies'), dissolves: () => request.get('/union/dissolve-applies'), records: () => request.get('/union/audit-records'),
  audit: (kind, id, result) => request.post(`/union/${kind}-applies/${id}/audit`, { result }),
  members: () => request.get('/union/members'), add: stuId => request.post('/union/members', { stuId }),
  remove: stuId => request.delete(`/union/members/${stuId}`), logs: () => request.get('/union/member-logs'),
}
