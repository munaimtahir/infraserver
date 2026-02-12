<template>
  <div class="system-card">
    <div class="header">
      <h2 class="title">System Status</h2>
      <HealthBadge :status="statusBadge" />
    </div>
    <div class="meta">
      <div>
        <span class="label">CPU Usage</span>
        <span class="value">{{ formatPercent(system?.cpu?.usagePercent) }}</span>
      </div>
      <div>
        <span class="label">RAM Usage</span>
        <span class="value">
          {{ formatPercent(system?.memory?.usagePercent) }}
          <small>({{ formatBytes(system?.memory?.usedBytes) }} / {{ formatBytes(system?.memory?.totalBytes) }})</small>
        </span>
      </div>
      <div>
        <span class="label">Disk Free</span>
        <span class="value">{{ formatBytes(system?.disk?.availableBytes) }}</span>
      </div>
      <div>
        <span class="label">Host Uptime</span>
        <span class="value">{{ formatUptime(system?.uptimeSeconds) }}</span>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  props: {
    system: {
      type: Object,
      default: () => ({ status: 'loading' })
    }
  },
  computed: {
    statusBadge() {
      if (!this.system) return 'unknown';
      if (this.system.status === 'ok') return 'healthy';
      if (this.system.status === 'error') return 'unhealthy';
      return 'unknown';
    }
  },
  methods: {
    formatPercent(value) {
      if (typeof value !== 'number' || Number.isNaN(value)) return 'n/a';
      return `${value.toFixed(1)}%`;
    },
    formatBytes(bytes) {
      if (typeof bytes !== 'number' || Number.isNaN(bytes) || bytes < 0) return 'n/a';
      if (bytes === 0) return '0 B';
      const units = ['B', 'KB', 'MB', 'GB', 'TB'];
      let val = bytes;
      let idx = 0;
      while (val >= 1024 && idx < units.length - 1) {
        val /= 1024;
        idx += 1;
      }
      return `${val >= 10 || idx === 0 ? val.toFixed(0) : val.toFixed(1)} ${units[idx]}`;
    },
    formatUptime(seconds) {
      if (typeof seconds !== 'number' || Number.isNaN(seconds) || seconds < 0) return 'n/a';
      const d = Math.floor(seconds / 86400);
      const h = Math.floor((seconds % 86400) / 3600);
      const m = Math.floor((seconds % 3600) / 60);
      if (d > 0) return `${d}d ${h}h`;
      if (h > 0) return `${h}h ${m}m`;
      return `${m}m`;
    }
  }
};
</script>

<style scoped>
.system-card {
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

.value small {
  color: var(--muted-2);
  font-weight: 500;
}
</style>
