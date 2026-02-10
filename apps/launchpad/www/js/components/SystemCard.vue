<template>
  <div class="system-card">
    <div class="card-content">
      <div class="header">
        <h3 class="system-name">{{ app.name }}</h3>
        <HealthBadge :status="app.overall" />
      </div>
      <div class="meta-row">
        <span>{{ app.containers?.length || 0 }} Containers</span>
        <span class="separator" v-if="timeAgoText !== 'N/A'">•</span>
        <span v-if="timeAgoText !== 'N/A'">Updated {{ timeAgoText }}</span>
        <span class="separator" v-if="app.urlStatus && app.urlStatus.status">•</span>
        <span v-if="app.urlStatus && app.urlStatus.status">
          Web: <span :class="urlStatusClass">{{ app.urlStatus.status }}</span>
        </span>
      </div>
    </div>
    <div class="card-footer">
      <span>View Details →</span>
    </div>
  </div>
</template>

<script>
export default {
  props: ['app'],
  computed: {
    timeAgoText() {
      if (!this.app.lastChecked) return 'N/A';
      const date = new Date(this.app.lastChecked);
      const seconds = Math.floor((Date.now() - date.getTime()) / 1000);
      if (seconds < 5) return `just now`;
      if (seconds < 60) return `${seconds}s ago`;
      const minutes = Math.floor(seconds / 60);
      if (minutes < 60) return `${minutes}m ago`;
      const hours = Math.floor(minutes / 60);
      return `${hours}h ago`;
    },
    urlStatusClass() {
      const status = this.app.urlStatus?.status?.toLowerCase();
      if (status === 'healthy' || status === 'reachable') return 'status-ok';
      if (status === 'unhealthy' || status === 'down') return 'status-bad';
      return 'status-unknown';
    }
  }
};
</script>

<style scoped>
.system-card {
  background-color: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--r-lg);
  padding: 20px 22px;
  cursor: pointer;
  transition: transform var(--t-base), border-color var(--t-base), box-shadow var(--t-base);
  box-shadow: var(--shadow-sm);
  display: flex;
  flex-direction: column;
  justify-content: space-between;
}

.system-card:hover {
  transform: translateY(-2px);
  border-color: var(--border-strong);
  box-shadow: var(--shadow-md);
}

.card-content {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
}

.system-name {
  font-size: 18px;
  font-weight: 600;
  color: var(--text);
  margin: 0;
}

.meta-row {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  color: var(--muted);
}

.separator {
  color: var(--muted-2);
  opacity: 0.6;
}

.status-ok {
  color: var(--ok);
  font-weight: 600;
}
.status-bad {
  color: var(--bad);
  font-weight: 600;
}
.status-unknown {
  color: var(--muted);
}

.card-footer {
  margin-top: 16px;
  text-align: right;
  font-size: 13px;
  font-weight: 500;
  color: var(--primary);
}
</style>
