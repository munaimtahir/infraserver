<template>
  <div class="systems-section">
    <h2 class="section-title">All Systems</h2>
    <div class="systems-grid">
      <SystemCard
        v-for="app in apps"
        :key="app.id"
        :app="app"
        @click="$emit('select-app', app)"
      />
    </div>
  </div>
</template>

<script>
export default {
  props: ['apps'],
  emits: ['select-app'],
};
</script>

<style scoped>
.systems-section {
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.section-title {
  font-size: 20px;
  font-weight: 600;
  color: var(--text);
  margin: 0;
  letter-spacing: -0.01em;
}
.systems-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(340px, 1fr));
  gap: 20px;
}
</style>