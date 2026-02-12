<template>
  <div class="global-status-bar">
    <div class="status-summary">
      <HealthBadge :status="overallStatus" class="overall-status-badge" />
      <div class="status-counts">
        <span class="count-item">
          <span class="dot ok"></span> {{ stats.healthy }} Healthy
        </span>
        <span class="count-item">
          <span class="dot warn"></span> {{ stats.degraded }} Degraded
        </span>
        <span class="count-item">
          <span class="dot bad"></span> {{ stats.down }} Down
        </span>
      </div>
    </div>
    <div class="meta-info">
      <span>Last sync: {{ timeAgoText }}</span>
    </div>
  </div>
</template>

<script>
export default {
  props: ['stats', 'lastSync'],
  computed: {
    overallStatus() {
      if (!this.stats) return 'unknown';
      if (this.stats.down > 0) return 'down';
      if (this.stats.degraded > 0) return 'degraded';
      if (this.stats.healthy > 0) return 'healthy';
      return 'unknown';
    },
    timeAgoText() {
        if (!this.lastSync) return 'Pending...';
        const date = new Date(this.lastSync);
        const seconds = Math.round((Date.now() - date.getTime()) / 1000);
        if (seconds < 2) return `1s ago`;
        if (seconds < 60) return `${seconds}s ago`;
        const minutes = Math.floor(seconds / 60);
        if (minutes < 2) return `1m ago`;
        if (minutes < 60) return `${minutes}m ago`;
        const hours = Math.floor(minutes / 60);
        if (hours < 2) return `1h ago`;
        return `${hours}h ago`;
    }
  }
};
</script>

<style scoped>
.global-status-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  background-color: var(--surface);
  padding: 14px 18px;
  border-radius: var(--r-md);
  border: 1px solid var(--border);
  box-shadow: var(--shadow-sm);
}

.status-summary {
  display: flex;
  align-items: center;
  gap: 16px;
}

.overall-status-badge {
  font-size: 13px;
  padding: 6px 12px;
  font-weight: 700;
}

.status-counts {
  display: flex;
  align-items: center;
  gap: 14px;
  font-size: 13px;
  color: var(--muted);
}

.count-item {
  display: flex;
  align-items: center;
  gap: 6px;
}

.dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
}
.dot.ok { background-color: var(--ok); }
.dot.warn { background-color: var(--warn); }
.dot.bad { background-color: var(--bad); }

.meta-info {
  font-size: 13px;
  color: var(--muted-2);
}
</style>
