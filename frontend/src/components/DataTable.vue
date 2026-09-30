<script setup>
import StatusTag from './StatusTag.vue'
defineProps({ rows: { type: Array, default: () => [] }, columns: { type: Array, default: () => [] }, loading: Boolean, empty: { type: String, default: '暂无记录' } })
</script>
<template><el-table :data="rows" v-loading="loading" :empty-text="empty" stripe class="data-table" :row-class-name="({ row }) => row.isDeleted ? 'deleted-row' : ''"><el-table-column v-for="col in columns" :key="col.key" :label="col.label" :min-width="col.width || 130" show-overflow-tooltip><template #default="{ row }"><StatusTag v-if="col.status" :value="row[col.key]" /><span v-else>{{ row[col.key] ?? '—' }}</span></template></el-table-column><el-table-column v-if="$slots.default" label="操作" :min-width="220" fixed="right"><template #default="{ row }"><slot :row="row" /></template></el-table-column></el-table></template>
