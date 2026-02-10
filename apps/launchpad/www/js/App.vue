<template>
  <div id="app-wrapper">
    <header class="app-header">
      <GlobalStatusBar :stats="stats" :last-sync="lastSync" />
      <CaddyStatusCard :caddy="caddy" />
    </header>
    <main class="app-main">
      <KPIMetricsRow :metrics="metrics" />
      <SystemsGrid :apps="apps" @select-app="setSelectedApp" />
    </main>
    <OperationsDrawer
      :app="selectedApp"
      v-if="selectedApp"
      @close="selectedApp = null"
      @update:app="updateApp"
    />
  </div>
</template>

<script>
import CaddyStatusCard from './components/CaddyStatusCard.vue';
export default {
  components: { CaddyStatusCard },
  data() {
    return {
      apps: [],
      selectedApp: null,
      stats: {
        healthy: 0,
        degraded: 0,
        down: 0,
      },
      metrics: {
        totalContainers: 0,
        running: 0,
        failed: 0,
        uptime: 'N/A',
        alerts: 0,
      },
      caddy: { status: 'loading' },
      lastSync: null,
      poller: null,
    };
  },
  methods: {
    async fetchApps() {
      try {
        const res = await fetch('/api/apps');
        if (!res.ok) throw new Error('Failed to load apps');
        const appData = await res.json();
        this.apps = appData.apps;
        this.updateComputedStats();
        this.lastSync = new Date().toISOString();
      } catch (error) {
        console.error('Failed to fetch apps', error);
      }
    },
    async fetchCaddy() {
      try {
        const res = await fetch('/api/caddy');
        if (!res.ok) throw new Error('Failed to load caddy');
        this.caddy = await res.json();
      } catch (error) {
        console.error('Failed to fetch caddy', error);
        this.caddy = { status: 'error', error: error.message };
      }
    },
    updateComputedStats() {
      if (!this.apps) {
        return;
      }
      let healthy = 0;
      let degraded = 0;
      let down = 0;
      let totalContainers = 0;
      let running = 0;
      let failed = 0;

      this.apps.forEach(app => {
        const status = app.overall ? app.overall.toLowerCase() : 'unknown';
        if (status === 'healthy' || status === 'online' || status === 'reachable') {
          healthy++;
        } else if (status === 'degraded' || status === 'partial' || status === 'starting') {
          degraded++;
        } else {
          down++;
        }
        
        if (app.containers) {
            totalContainers += app.containers.length;
            app.containers.forEach(c => {
                const containerStatus = c.status ? c.status.toLowerCase() : 'unknown';
                if (containerStatus === 'running' || containerStatus === 'healthy' || containerStatus === 'online') {
                    running++;
                } else {
                    failed++;
                }
            });
        }
      });

      this.stats = { healthy, degraded, down };
      this.metrics = { totalContainers, running, failed, uptime: 'N/A', alerts: 0 };
    },
    setSelectedApp(app) {
      this.selectedApp = app;
    },
    updateApp(updated) {
      this.apps = this.apps.map(a => (a.id === updated.id ? updated : a));
      this.updateComputedStats();
      this.selectedApp = updated;
    },
    startPolling() {
      this.stopPolling();
      this.poller = setInterval(() => {
        this.fetchApps();
        this.fetchCaddy();
      }, 30000);
    },
    stopPolling() {
      if (this.poller) {
        clearInterval(this.poller);
        this.poller = null;
      }
    },
  },
  created() {
    this.fetchApps();
    this.fetchCaddy();
    this.startPolling();
  },
  beforeUnmount() {
    this.stopPolling();
  }
};
</script>

<style>
#app-wrapper {
  padding: 0 32px;
  max-width: 1400px;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  gap: 28px;
  padding-bottom: 64px;
}

.app-header {
  padding-top: 24px;
  display: grid;
  grid-template-columns: 1fr;
  gap: 22px;
}

.app-main {
  display: flex;
  flex-direction: column;
  gap: 28px;
}

@media (min-width: 960px) {
  .app-header {
    grid-template-columns: 1.1fr 0.9fr;
    gap: 24px;
    padding-top: 32px;
  }
}
</style>
