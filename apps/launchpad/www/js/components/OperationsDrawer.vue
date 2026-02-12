<template>
  <div class="drawer-overlay" @click.self="$emit('close')">
    <div class="drawer-panel">
      <div class="drawer-header">
        <div class="header-main">
          <h2 class="app-name">{{ app.name }}</h2>
          <HealthBadge :status="app.overall" />
        </div>
        <button class="close-btn" @click="$emit('close')" aria-label="Close">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" width="20" height="20">
            <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
          </svg>
        </button>
      </div>

      <div class="drawer-content">
        <CollapsibleSection title="Live Status" start-open>
          <div class="status-grid">
            <div class="status-card">
              <p class="status-label">Public URL Access</p>
              <div class="status-value">
                <HealthBadge :status="app?.urlStatus?.status || 'unknown'" />
              </div>
              <p class="status-meta">{{ formatStatusMeta(app?.urlStatus) }}</p>
            </div>
            <div class="status-card">
              <p class="status-label">Health Endpoint</p>
              <div class="status-value">
                <HealthBadge :status="app?.health?.status || 'unknown'" />
              </div>
              <p class="status-meta">{{ formatStatusMeta(app?.health) }}</p>
            </div>
          </div>
        </CollapsibleSection>

        <CollapsibleSection title="Memory & Image Usage" start-open>
          <div class="usage-grid">
            <div class="usage-card">
              <p class="usage-label">Container RAM In Use</p>
              <p class="usage-value">{{ formatBytes(app?.resourceUsage?.runtimeMemoryBytes) }}</p>
            </div>
            <div class="usage-card">
              <p class="usage-label">Container RAM Limit</p>
              <p class="usage-value">{{ formatBytes(app?.resourceUsage?.runtimeMemoryLimitBytes) }}</p>
            </div>
            <div class="usage-card">
              <p class="usage-label">Active Image Storage</p>
              <p class="usage-value">{{ formatBytes(app?.resourceUsage?.totalImageBytes) }}</p>
            </div>
            <div class="usage-card highlight">
              <p class="usage-label">Reclaimable Old Builds</p>
              <p class="usage-value">{{ formatBytes(app?.resourceUsage?.reclaimableBytes) }}</p>
            </div>
          </div>
          <p class="usage-note">
            Inactive image candidates:
            <strong>{{ app?.resourceUsage?.purgeCandidatesCount ?? 0 }}</strong>
            {{ (app?.resourceUsage?.purgeCandidatesCount || 0) === 1 ? 'image' : 'images' }}
          </p>
          <div v-if="(app?.resourceUsage?.purgeCandidatesCount || 0) > 0" class="candidate-list">
            <div
              v-for="candidate in app.resourceUsage.purgeCandidates"
              :key="candidate.id"
              class="candidate-item"
            >
              <span class="candidate-tag">{{ candidate.tags?.[0] || candidate.shortId }}</span>
              <span class="candidate-size">{{ formatBytes(candidate.sizeBytes) }}</span>
            </div>
          </div>
          <div class="usage-actions">
            <ActionButton
              variant="outline"
              :disabled="!canAct"
              :is-loading="pendingAction === 'purge-images'"
              @click="showPurgeImagesModal = true"
            >
              Purge Unused Images
            </ActionButton>
          </div>
        </CollapsibleSection>

        <CollapsibleSection title="Actions" start-open>
          <div class="action-groups">
            <div class="action-group">
              <h4 class="group-title">Primary</h4>
              <ActionButton :disabled="isActionBusy || !app?.url" @click="openLink('app', app.url)" :is-loading="pendingAction === 'open-app'">Open App</ActionButton>
              <ActionButton :disabled="!canAct" @click="performAction('refresh')" :is-loading="pendingAction === 'refresh'">Refresh Status</ActionButton>
            </div>
            <div class="action-group">
              <h4 class="group-title">Maintenance</h4>
              <ActionButton variant="outline" :disabled="!canAct || !hasContainers" @click="performAction('restart-app')" :is-loading="pendingAction === 'restart-app'">Restart All</ActionButton>
              <ActionButton variant="outline" :disabled="!canAct || !hasContainers" @click="performAction('pull-restart-app')" :is-loading="pendingAction === 'pull-restart-app'">Pull & Restart</ActionButton>
            </div>
             <div class="action-group">
              <h4 class="group-title">Diagnostics</h4>
              <ActionButton variant="ghost" :disabled="!canAct" @click="performAction('verify-public')" :is-loading="pendingAction === 'verify-public'">Verify Public URL</ActionButton>
              <ActionButton variant="ghost" :disabled="isActionBusy || !app?.healthUrl" @click="openLink('health', app.healthUrl)" :is-loading="pendingAction === 'open-health'">Check Health Endpoint</ActionButton>
            </div>
            <div class="action-group danger-zone">
              <h4 class="group-title">Danger Zone</h4>
              <ActionButton variant="danger" :disabled="!canAct || !hasContainers" @click="showStopAllModal = true">Stop All Containers</ActionButton>
            </div>
          </div>
        </CollapsibleSection>

        <CollapsibleSection title="Containers" :subtitle="`${app.containers?.length || 0} running`" start-open>
          <div class="container-list" v-if="hasContainers">
            <div v-for="container in app.containers" :key="container.name" class="container-item">
              <div class="container-info">
                <span class="container-name">{{ container.name }}</span>
                <span class="container-id">{{ formatContainerId(container) }}</span>
              </div>
              <HealthBadge :status="container.status" />
              <div class="container-actions">
                <ActionButton variant="ghost" size="sm" :disabled="pendingContainer === container.name" @click="performContainerAction(container.name, 'start')">Start</ActionButton>
                <ActionButton variant="ghost" size="sm" :disabled="pendingContainer === container.name" @click="performContainerAction(container.name, 'restart')">Restart</ActionButton>
                <ActionButton variant="ghost" size="sm" :disabled="pendingContainer === container.name" @click="showStopSingleModal = container.name">Stop</ActionButton>
              </div>
            </div>
          </div>
          <p v-else class="no-items-text">No containers configured for this application.</p>
        </CollapsibleSection>
      </div>

      <div class="drawer-toast" v-if="message" :class="messageType">
        <p>{{ message }}</p>
      </div>
    </div>

    <ConfirmationModal
      v-if="showStopAllModal"
      title="Stop All Containers"
      :message="`Are you sure you want to stop all containers for ${app.name}? This action is irreversible.`"
      require-confirmation-text
      :confirmation-text="app.name"
      @close="showStopAllModal = false"
      @confirm="stopAllContainers"
    />
    <ConfirmationModal
      v-if="showStopSingleModal"
      title="Stop Container"
      :message="`Are you sure you want to stop container ${showStopSingleModal}?`"
      @close="showStopSingleModal = null"
      @confirm="stopSingleContainer"
    />
    <ConfirmationModal
      v-if="showPurgeImagesModal"
      title="Purge Unused Images"
      :message="`Remove ${app?.resourceUsage?.purgeCandidatesCount || 0} unused image candidate(s) for ${app.name}? This only targets inactive images linked to this app.`"
      require-confirmation-text
      confirmation-text="PURGE"
      @close="showPurgeImagesModal = false"
      @confirm="confirmPurgeImages"
    />
  </div>
</template>

<script>
import ActionButton from './ActionButton.vue';

export default {
  props: ['app'],
  emits: ['close', 'update:app'],
  components: { ActionButton },
  data() {
    return {
      showStopAllModal: false,
      showStopSingleModal: null,
      message: '',
      messageType: '', // 'success' or 'error'
      pendingAction: null,
      pendingContainer: '',
      showPurgeImagesModal: false,
      messageTimeout: null,
    }
  },
  computed: {
    isActionBusy() { return !!this.pendingAction; },
    canAct() { return !!(this.app && this.app.id) && !this.isActionBusy; },
    hasContainers() { return Array.isArray(this.app?.containers) && this.app.containers.length > 0; }
  },
  mounted() {
    document.addEventListener('keydown', this.handleKeydown);
    this.refreshApp();
  },
  beforeUnmount() {
    document.removeEventListener('keydown', this.handleKeydown);
    if (this.messageTimeout) clearTimeout(this.messageTimeout);
  },
  methods: {
    handleKeydown(e) { if (e.key === 'Escape') this.$emit('close'); },
    showMessage(msg, type = 'success', duration = 4000) {
      this.message = msg;
      this.messageType = type;
      if (this.messageTimeout) clearTimeout(this.messageTimeout);
      this.messageTimeout = setTimeout(() => { this.message = ''; }, duration);
    },
    openLink(kind, url) {
      if (!url) {
        this.showMessage(`${kind === 'app' ? 'App URL' : 'Health URL'} not configured.`, 'error');
        return;
      }
      window.open(url, '_blank', 'noopener,noreferrer');
    },
    async performAction(action) {
      if (this.pendingAction) return;
      this.pendingAction = action;
      try {
        const actionMap = {
          'restart-app': { endpoint: 'restart', method: 'POST' },
          'pull-restart-app': { endpoint: 'pull-restart', method: 'POST' },
          'verify-public': { endpoint: 'verify-url', method: 'GET' },
          'stop-app': { endpoint: 'stop', method: 'POST' },
          'refresh': { endpoint: 'refresh', method: 'POST' },
          'purge-images': { endpoint: 'purge-images', method: 'POST' },
        };
        const { endpoint, method } = actionMap[action] || { endpoint: action, method: 'POST' };
        const res = await fetch(`/api/apps/${this.app.id}/${endpoint}`, { method });
        if (!res.ok) throw new Error(`Request failed with status ${res.status}`);
        const data = await res.json();
        
        await this.refreshApp(); // Always refresh app data after an action

        if (action === 'pull-restart-app') {
            const failedPulls = data.pull?.filter(r => !r.success) || [];
            const failedRestarts = data.restart?.filter(r => !r.success) || [];
            if (failedPulls.length > 0 || failedRestarts.length > 0) {
                let errorMsg = '';
                if (failedPulls.length > 0) errorMsg += `Pull failed for: ${failedPulls.map(r => r.name).join(', ')}. `;
                if (failedRestarts.length > 0) errorMsg += `Restart failed for: ${failedRestarts.map(r => r.name).join(', ')}.`;
                this.showMessage(`Pull & Restart completed with errors: ${errorMsg}`, 'error', 8000);
            } else {
                this.showMessage('Pull & Restart successful!', 'success');
            }
        } else if (action === 'refresh') {
            this.showMessage('Status refreshed successfully.', 'success');
        } else if (action === 'purge-images') {
            const removed = data.removedCount ?? 0;
            const failed = data.failedCount ?? 0;
            const reclaimed = this.formatBytes(data.reclaimedBytes ?? 0);
            this.showMessage(`Image purge finished. Removed ${removed}, failed ${failed}, reclaimed ${reclaimed}.`, failed > 0 ? 'error' : 'success', 8000);
        }
        else {
            this.showMessage(data.message || `${action} completed.`, 'success');
        }

      } catch(e) {
        this.showMessage(`Action failed: ${e.message}`, 'error');
      } finally {
        this.pendingAction = null;
      }
    },
    async performContainerAction(name, action) {
      if (this.pendingContainer) return;
      this.pendingContainer = name;
      try {
        const res = await fetch(`/api/containers/${name}/${action}`, { method: 'POST' });
        const data = await res.json();
        if (!res.ok || !data.success) {
          throw new Error(data.error || 'Container action failed');
        }
        await this.refreshApp(); // Always refresh app data after an action
        this.showMessage(`${name} ${action} successful!`, 'success');
      } catch(e) {
        this.showMessage(`Container action failed: ${e.message}`, 'error');
      } finally {
        this.pendingContainer = '';
      }
    },
    async refreshApp() {
      try {
        const res = await fetch(`/api/apps/${this.app.id}`);
        if (!res.ok) throw new Error('Failed to refresh app state');
        const latest = await res.json();
        this.$emit('update:app', latest);
      } catch (e) {
        this.showMessage('Could not refresh app data.', 'error');
      }
    },
    async stopAllContainers() {
      this.showStopAllModal = false;
      await this.performAction('stop-app');
    },
    async stopSingleContainer() {
      const containerName = this.showStopSingleModal;
      this.showStopSingleModal = null;
      await this.performContainerAction(containerName, 'stop');
    },
    async confirmPurgeImages() {
      this.showPurgeImagesModal = false;
      await this.performAction('purge-images');
    },
    formatContainerId(container) {
      const id = container?.shortId || container?.id;
      if (!id) return 'n/a';
      return id.substring(0, 12);
    },
    formatBytes(bytes) {
      if (typeof bytes !== 'number' || Number.isNaN(bytes) || bytes < 0) return 'n/a';
      if (bytes === 0) return '0 B';
      const units = ['B', 'KB', 'MB', 'GB', 'TB'];
      let value = bytes;
      let unitIndex = 0;
      while (value >= 1024 && unitIndex < units.length - 1) {
        value /= 1024;
        unitIndex += 1;
      }
      const formatted = value >= 10 || unitIndex === 0 ? value.toFixed(0) : value.toFixed(1);
      return `${formatted} ${units[unitIndex]}`;
    },
    formatStatusMeta(statusObj) {
      if (!statusObj) return 'No status data available.';
      if (statusObj.error) return `Error: ${statusObj.error}`;
      if (statusObj.statusCode) return `HTTP ${statusObj.statusCode}`;
      return 'No additional diagnostics.';
    },
  }
};
</script>

<style>
/* ActionButton Styles (globally available in this component) */
.action-btn {
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  white-space: nowrap;
  border-radius: var(--r-sm);
  font-size: 14px;
  font-weight: 600;
  padding: 0 14px;
  height: 36px;
  cursor: pointer;
  user-select: none;
  border: 1px solid transparent;
  transition: all var(--t-fast);
}
.action-btn:focus-visible {
  outline: 2px solid rgba(29, 78, 216, 0.35);
  outline-offset: 1px;
}
.action-btn .btn-text {
  transition: opacity var(--t-fast);
}
.action-btn.is-loading .btn-text {
  opacity: 0;
}
.action-btn:disabled {
  opacity: 0.55;
  cursor: not-allowed;
}
.action-btn:active:not(:disabled) {
  transform: scale(0.98);
}
.action-btn.sm { height: 32px; padding: 0 10px; font-size: 13px; }

/* Variants */
.action-btn.primary { background-color: var(--primary); color: white; }
.action-btn.primary:hover:not(:disabled) { background-color: var(--primary-hover); }

.action-btn.outline { background-color: transparent; color: var(--text); border-color: var(--border-strong); }
.action-btn.outline:hover:not(:disabled) { background-color: var(--surface-2); border-color: var(--border-strong); }

.action-btn.ghost { background-color: transparent; color: var(--muted); }
.action-btn.ghost:hover:not(:disabled) { background-color: var(--surface-2); color: var(--text); }

.action-btn.danger { background-color: transparent; color: var(--bad); border-color: var(--bad); }
.action-btn.danger:hover:not(:disabled) { background-color: var(--bad-bg); }

/* Spinner */
.spinner {
  position: absolute;
  width: 16px;
  height: 16px;
  border: 2px solid var(--primary);
  border-top-color: transparent;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}
.action-btn.primary .spinner { border-color: white; border-top-color: transparent; }
.action-btn.danger .spinner { border-color: var(--bad); border-top-color: transparent; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>

<style scoped>
.drawer-overlay {
  position: fixed;
  inset: 0;
  background-color: rgba(11, 18, 32, 0.6);
  backdrop-filter: blur(4px);
  z-index: 100;
  display: flex;
  justify-content: flex-end;
  animation: fadeIn 200ms var(--t-base) forwards;
  pointer-events: none; /* Allow clicks to pass through the overlay */
}

.drawer-panel {
  width: 100%;
  max-width: 680px;
  height: 100%;
  background-color: var(--bg);
  box-shadow: var(--shadow-xl);
  display: flex;
  flex-direction: column;
  animation: slideIn 300ms var(--t-base) forwards;
  pointer-events: auto; /* Make the panel interactive */
}

@keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
@keyframes slideIn { from { transform: translateX(100%); } to { transform: translateX(0); } }

.drawer-header {
  flex-shrink: 0;
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 24px;
  border-bottom: 1px solid var(--border);
  background: var(--surface);
}

.header-main {
  display: flex;
  align-items: center;
  gap: 12px;
}
.app-name {
  font-size: 20px;
  font-weight: 600;
  margin: 0;
  color: var(--text);
}
.close-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: none;
  border: none;
  color: var(--muted);
  cursor: pointer;
  transition: all var(--t-fast);
}
.close-btn:hover { background-color: var(--surface-2); color: var(--text); }

.drawer-content {
  flex-grow: 1;
  overflow-y: auto;
  padding: 24px;
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.status-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 12px;
}

.status-card {
  border: 1px solid var(--border);
  border-radius: var(--r-md);
  background-color: var(--surface-2);
  padding: 12px;
}

.status-label {
  margin: 0 0 8px;
  font-size: 12px;
  font-weight: 600;
  color: var(--muted);
}

.status-value {
  margin-bottom: 8px;
}

.status-meta {
  margin: 0;
  font-size: 12px;
  color: var(--muted-2);
}

.usage-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 12px;
}

.usage-card {
  border: 1px solid var(--border);
  border-radius: var(--r-md);
  background-color: var(--surface-2);
  padding: 12px;
}

.usage-card.highlight {
  border-color: rgba(180, 83, 9, 0.35);
  background-color: var(--warn-bg);
}

.usage-label {
  margin: 0 0 6px;
  font-size: 12px;
  font-weight: 600;
  color: var(--muted);
}

.usage-value {
  margin: 0;
  font-size: 20px;
  font-weight: 700;
  color: var(--text);
}

.usage-note {
  margin: 12px 0 0;
  font-size: 13px;
  color: var(--muted);
}

.usage-actions {
  margin-top: 12px;
  display: flex;
  justify-content: flex-end;
}

.candidate-list {
  margin-top: 10px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.candidate-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  border: 1px solid var(--border);
  border-radius: var(--r-sm);
  padding: 8px 10px;
  background: var(--surface);
}

.candidate-tag {
  font-family: var(--font-family-mono);
  font-size: 12px;
  color: var(--text);
  overflow-wrap: anywhere;
}

.candidate-size {
  font-size: 12px;
  font-weight: 600;
  color: var(--warn);
}

.action-groups {
  display: flex;
  flex-direction: column;
  gap: 20px;
}
.action-group {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 10px;
}
.group-title {
  font-size: 13px;
  font-weight: 600;
  color: var(--muted);
  margin: 0;
  width: 110px;
  flex-shrink: 0;
}
.danger-zone {
  border-top: 1px solid var(--border);
  padding-top: 20px;
}
.danger-zone .group-title {
  color: var(--bad);
}

.container-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.container-item {
  display: grid;
  grid-template-columns: 1fr auto auto;
  align-items: center;
  padding: 10px 12px;
  border-radius: var(--r-md);
  background-color: var(--surface);
  border: 1px solid var(--border);
  gap: 16px;
}
.container-info {
  display: flex;
  flex-direction: column;
}
.container-name {
  font-size: 14px;
  font-weight: 600;
  color: var(--text);
}
.container-id {
  font-family: var(--font-family-mono);
  font-size: 12px;
  color: var(--muted-2);
}
.container-actions {
  display: flex;
  gap: 4px;
}
.no-items-text {
  font-size: 14px;
  color: var(--muted);
  text-align: center;
  padding: 20px;
  background-color: var(--surface-2);
  border-radius: var(--r-md);
}

.drawer-toast {
  flex-shrink: 0;
  padding: 12px 24px;
  margin: 16px;
  border-radius: var(--r-md);
  font-size: 14px;
  font-weight: 500;
  box-shadow: var(--shadow-lg);
  animation: toastIn 300ms var(--t-base) forwards;
}
@keyframes toastIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }

.drawer-toast p { margin: 0; }
.drawer-toast.success { background-color: #059669; color: white; } /* Darker success */
.drawer-toast.error { background-color: var(--bad); color: white; }
</style>
