<template>
  <div id="app-wrapper">
    <header class="app-header">
      <GlobalStatusBar :stats="stats" :last-sync="lastSync" />
      <div class="right-status-cards">
        <CaddyStatusCard :caddy="caddy" />
        <SystemStatusCard :system="systemStatus" />
      </div>
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
import SystemStatusCard from './components/SystemStatusCard.vue';
export default {
  components: { CaddyStatusCard, SystemStatusCard },
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
      systemStatus: { status: 'loading' },
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
        if (this.selectedApp?.id) {
          const updated = this.apps.find(a => a.id === this.selectedApp.id);
          if (updated) {
            this.selectedApp = {
              ...updated,
              resourceUsage: this.selectedApp.resourceUsage || updated.resourceUsage || null,
            };
          }
        }
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
    async fetchSystemStatus() {
      try {
        const res = await fetch('/api/system');
        if (!res.ok) throw new Error('Failed to load system status');
        this.systemStatus = await res.json();
      } catch (error) {
        console.error('Failed to fetch system status', error);
        this.systemStatus = { status: 'error', error: error.message };
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
        this.fetchSystemStatus();
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
    this.fetchSystemStatus();
    this.startPolling();
  },
  beforeUnmount() {
    this.stopPolling();
  }
};
</script>

<style>
:root {
  /* Base Palette */
  --bg: #F7F8FC;
  --surface: #FFFFFF;
  --surface-2: #F2F4F8;
  --border: rgba(15, 23, 42, 0.08);
  --border-strong: rgba(15, 23, 42, 0.14);

  /* Text Palette */
  --text: #0B1220;
  --muted: rgba(11, 18, 32, 0.70);
  --muted-2: rgba(11, 18, 32, 0.55);

  /* Brand Accent */
  --primary: #1D4ED8;
  --primary-hover: #1E40AF;
  --primary-bg: rgba(29, 78, 216, 0.07);

  /* Status Palette */
  --ok-bg: rgba(16, 185, 129, 0.1);
  --ok: #047857;
  --warn-bg: rgba(245, 158, 11, 0.12);
  --warn: #B45309;
  --bad-bg: rgba(239, 68, 68, 0.1);
  --bad: #B91C1C;
  --partial-bg: rgba(99, 102, 241, 0.1);
  --partial: #4338CA;
  --unknown-bg: #e5e7eb;
  --unknown: #4b5563;

  /* Shadows */
  --shadow-sm: 0 1px 2px rgba(2, 6, 23, 0.04), 0 1px 3px rgba(2,6,23,0.06);
  --shadow-md: 0 4px 6px -1px rgba(2, 6, 23, 0.05), 0 2px 4px -2px rgba(2, 6, 23, 0.05);
  --shadow-lg: 0 10px 15px -3px rgba(2, 6, 23, 0.06), 0 4px 6px -4px rgba(2, 6, 23, 0.06);
  --shadow-xl: 0 20px 25px -5px rgba(2, 6, 23, 0.07), 0 8px 10px -6px rgba(2, 6, 23, 0.07);

  /* Radii */
  --r-sm: 6px;
  --r-md: 12px;
  --r-lg: 16px;

  /* Transitions */
  --t-fast: 120ms cubic-bezier(.2,.8,.2,1);
  --t-base: 180ms cubic-bezier(.2,.8,.2,1);

  /* Typography */
  --font-family-sans: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  --font-family-mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
}

/* Global Styles & Resets */
*, *::before, *::after { box-sizing: border-box; }
body {
  margin: 0;
  font-family: var(--font-family-sans);
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  background-color: var(--bg);
  color: var(--text);
}

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

.right-status-cards {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

@media (min-width: 960px) {
  .app-header {
    grid-template-columns: 1.1fr 0.9fr;
    gap: 24px;
    padding-top: 32px;
  }
}
</style>
