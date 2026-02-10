<template>
  <div class="collapsible-section">
    <div class="section-header" @click="toggle">
      <div class="header-text">
        <h3 class="title">{{ title }}</h3>
        <span v-if="subtitle" class="subtitle">{{ subtitle }}</span>
      </div>
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="chevron" :class="{ open: isOpen }">
        <path fill-rule="evenodd" d="M5.22 8.22a.75.75 0 011.06 0L10 11.94l3.72-3.72a.75.75 0 111.06 1.06l-4.25 4.25a.75.75 0 01-1.06 0L5.22 9.28a.75.75 0 010-1.06z" clip-rule="evenodd" />
      </svg>
    </div>
    <div v-if="isOpen" class="section-content">
      <slot></slot>
    </div>
  </div>
</template>

<script>
export default {
  props: {
    title: String,
    subtitle: String,
    startOpen: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      isOpen: this.startOpen,
    };
  },
  methods: {
    toggle() {
      this.isOpen = !this.isOpen;
    },
  },
};
</script>

<style scoped>
.collapsible-section {
  background-color: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--r-md);
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 14px 16px;
  cursor: pointer;
  user-select: none;
}
.section-header:hover {
  background-color: var(--surface-2);
}

.header-text {
  display: flex;
  align-items: baseline;
  gap: 10px;
}

.title {
  font-size: 16px;
  font-weight: 600;
  margin: 0;
  color: var(--text);
}

.subtitle {
  font-size: 14px;
  color: var(--muted);
}

.chevron {
  width: 20px;
  height: 20px;
  color: var(--muted-2);
  transition: transform var(--t-base);
}
.chevron.open {
  transform: rotate(180deg);
}

.section-content {
  padding: 16px;
  border-top: 1px solid var(--border);
}
</style>
