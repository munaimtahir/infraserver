<template>
  <div class="kpi-metrics-grid">
    <div class="stat-tile">
      <span class="value">{{ metrics.totalContainers }}</span>
      <span class="label">Total Containers</span>
    </div>
    <div class="stat-tile">
      <span class="value">{{ metrics.running }}</span>
      <span class="label">Containers Running</span>
    </div>
    <div class="stat-tile">
      <span class="value down">{{ metrics.failed }}</span>
      <span class="label">Containers Down</span>
    </div>
    <div class="stat-tile">
      <span class="value">{{ metrics.uptime }}</span>
      <span class="label">Avg. Uptime</span>
    </div>
    <div class="stat-tile">
      <span class="value warn">{{ metrics.alerts }}</span>
      <span class="label">Active Alerts</span>
    </div>
  </div>
</template>

<script>
export default {
  props: ['metrics'],
};
</script>

<style scoped>
.kpi-metrics-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
  gap: 16px;
}
.stat-tile {
  background-color: var(--surface);
  padding: 20px;
  border-radius: var(--r-md);
  border: 1px solid var(--border);
  display: flex;
  flex-direction: column;
  gap: 4px;
  text-align: left;
}
.value {
  font-size: 28px;
  font-weight: 600;
  line-height: 1.2;
  color: var(--text);
  letter-spacing: -0.01em;
}
.label {
  font-size: 13px;
  color: var(--muted);
}
.value.down {
  color: var(--bad);
}
.value.warn {
  color: var(--warn);
}
</style>
