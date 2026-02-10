<template>
  <div class="caddy-card">
    <div class="header">
      <h2 class="title">Caddy Edge Proxy</h2>
      <HealthBadge :status="statusBadge" />
    </div>
    <div class="meta">
      <div>
        <span class="label">Config</span>
        <span class="value">{{ validationText }}</span>
      </div>
      <div>
        <span class="label">Last Reload</span>
        <span class="value">{{ lastReloadText }}</span>
      </div>
    </div>
    <!-- Routes and Logs can be added back if needed, hiding for minimalism -->
  </div>
</template>

<script>
export default {
  props: {
    caddy: {
      type: Object,
      default: () => ({ status: 'loading' })
    }
  },
  computed: {
    statusBadge() {
      if (!this.caddy) return 'unknown';
      if (this.caddy.status === 'ok') return 'healthy';
      if (this.caddy.status === 'error') return 'unhealthy';
      return this.caddy.status;
    },
    validationText() {
      if (!this.caddy) return 'Loading...';
      if (this.caddy.status === 'ok') return 'Valid & Loaded';
      return this.caddy.error || 'Error';
    },
    lastReloadText() {
      if (!this.caddy || !this.caddy.lastReload) return '—';
      const date = new Date(this.caddy.lastReload);
      const seconds = Math.round((Date.now() - date.getTime()) / 1000);
      if (seconds < 60) return `${seconds}s ago`;
      const minutes = Math.round(seconds / 60);
      return `${minutes}m ago`;
    }
  }
};
</script>

<style scoped>
.caddy-card {
  background-color: var(--surface);
  padding: 18px 20px;
  border-radius: var(--r-md);
  border: 1px solid var(--border);
  box-shadow: var(--shadow-sm);
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.title {
  font-size: 18px;
  font-weight: 600;
  margin: 0;
  color: var(--text);
}

.meta {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.label {
  display: block;
  color: var(--muted);
  font-size: 13px;
  margin-bottom: 2px;
}

.value {
  font-weight: 600;
  font-size: 14px;
  color: var(--text);
}
</style>
