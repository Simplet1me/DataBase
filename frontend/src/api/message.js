import request from '../utils/request'
export const messageApi = {
  list: () => request.get('/messages'), save: (data, id) => id ? request.put(`/messages/${id}`, data) : request.post('/messages', data),
  remove: id => request.delete(`/messages/${id}`),
}
