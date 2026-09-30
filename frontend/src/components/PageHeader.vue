<script setup>defineProps({ title: String, subtitle: String, eyebrow: { type: String, default: 'CAMPUS LIFE' } })</script>
<template><div class="page-heading"><div><div class="eyebrow">{{ eyebrow }}</div><h1>{{ title }}</h1><p>{{ subtitle }}</p></div><div class="heading-actions"><slot /></div></div></template>
