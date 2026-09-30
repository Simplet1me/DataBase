<script setup>
import { ref, reactive, watch } from 'vue'
const props = defineProps({ modelValue: Boolean, title: String, fields: Array, initial: Object, save: Function })
const emit = defineEmits(['update:modelValue', 'saved'])
const form = ref(), data = reactive({}), busy = ref(false)
watch(() => props.modelValue, open => { if (open) { Object.keys(data).forEach(k => delete data[k]); Object.assign(data, props.initial || {}); form.value?.clearValidate() } })
async function submit() {
  if (!await form.value.validate().catch(() => false)) return
  busy.value = true
  try { await props.save({ ...data }); emit('update:modelValue', false); emit('saved') } catch {} finally { busy.value = false }
}
</script>
<template><el-dialog :model-value="modelValue" :title="title" width="min(580px, 94vw)" :close-on-click-modal="false" @update:model-value="emit('update:modelValue', $event)"><el-form ref="form" :model="data" label-position="top" @submit.prevent="submit"><el-form-item v-for="field in fields" :key="field.key" :label="field.label" :prop="field.key" :rules="[{ required: !field.optional, message: `请填写${field.label}`, trigger: 'blur' }]"><el-date-picker v-if="field.type === 'datetime'" v-model="data[field.key]" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" format="YYYY-MM-DD HH:mm:ss" style="width:100%" /><el-input v-else v-model="data[field.key]" :type="field.type || 'text'" :maxlength="field.max || 100" :rows="5" :show-password="field.type === 'password'" :show-word-limit="field.type === 'textarea'" /></el-form-item></el-form><template #footer><el-button @click="emit('update:modelValue', false)">取消</el-button><el-button type="primary" :loading="busy" @click="submit">保存</el-button></template></el-dialog></template>
