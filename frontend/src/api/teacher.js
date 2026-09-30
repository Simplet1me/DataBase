import request from '../utils/request'
export const teacherApi = {
  creates: () => request.get('/teacher/create-applies'), dissolves: () => request.get('/teacher/dissolve-applies'),
  club: () => request.get('/teacher/club'), activities: () => request.get('/teacher/activities'),
  audit: (kind, id, result) => request.post(`/teacher/${kind}/${id}/audit`, { result }),
}
