<script setup>
defineProps({ value: [String, Number] })
const labels = { pending: '待审批', agree: '已同意', reject: '已驳回', success: '已完成', fail: '已终止', wait_audit: '待审批', running: '进行中', finish: '已结束', president: '社长', vice_president: '副社长', member: '普通社员', quit: '主动退社', kick: '被移出', add: '新增成员', remove: '移除成员' }
const types = { pending: 'warning', wait_audit: 'warning', agree: 'success', success: 'success', running: 'success', reject: 'danger', fail: 'danger', president: 'danger', vice_president: 'warning' }
</script>
<template><el-tag :type="types[value] || 'info'" effect="light" round>{{ labels[value] || value || '—' }}</el-tag></template>
