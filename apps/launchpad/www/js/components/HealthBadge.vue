<template>
  <span class="health-badge" :class="statusClass">{{ formattedStatus }}</span>
</template>

<script>
export default {
  props: ['status'],
  computed: {
    formattedStatus() {
      if (!this.status) return 'Unknown';
      // Convert snake_case or kebab-case to Title Case
      return this.status
        .replace(/_/g, ' ')
        .replace(/-/g, ' ')
        .replace(/\w\S*/g, (txt) => txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase());
    },
    statusClass() {
      const s = this.status ? this.status.toLowerCase() : 'unknown';
      if (s === 'healthy' || s === 'online' || s === 'reachable') {
        return 'ok';
      } else if (s === 'degraded' || s === 'starting') {
        return 'warn';
      } else if (s === 'partial') {
        return 'partial';
      } else if (s === 'down' || s === 'unhealthy' || s === 'error' || s === 'offline') {
        return 'bad';
      } else {
        return 'unknown';
      }
    }
  }
}
</script>

<style scoped>
.health-badge {
  display: inline-block;
  padding: 5px 10px;
  border-radius: var(--r-sm);
  font-size: 12px;
  font-weight: 600;
  line-height: 1.4;
  text-align: center;
  white-space: nowrap;
}

.ok {
  background-color: var(--ok-bg);
  color: var(--ok);
}

.warn {
  background-color: var(--warn-bg);
  color: var(--warn);
}

.partial {
  background-color: var(--partial-bg);
  color: var(--partial);
}

.bad {
  background-color: var(--bad-bg);
  color: var(--bad);
}

.unknown {
  background-color: var(--unknown-bg);
  color: var(--unknown);
}
</style>
