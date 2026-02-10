<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal-panel">
      <h3 class="modal-title">{{ title }}</h3>
      <p class="modal-message">{{ message }}</p>

      <div class="confirmation-area" v-if="requireConfirmationText">
        <p class="confirmation-prompt">To confirm, please type "<strong>{{ confirmationText }}</strong>" below.</p>
        <input class="confirmation-input" type="text" v-model="userInput" @keyup.enter="confirm" />
      </div>

      <div class="modal-actions">
        <ActionButton variant="outline" @click="$emit('close')">Cancel</ActionButton>
        <ActionButton variant="danger" @click="confirm" :disabled="!canConfirm">Confirm Action</ActionButton>
      </div>
    </div>
  </div>
</template>

<script>
// Local, single-file component for buttons
const ActionButton = {
  name: 'ActionButton',
  props: {
    variant: { type: String, default: 'primary' },
    disabled: Boolean,
  },
  template: `
    <button :class="['action-btn', variant]" :disabled="disabled">
      <slot></slot>
    </button>
  `,
};

export default {
  props: {
    title: String,
    message: String,
    requireConfirmationText: {
      type: Boolean,
      default: false,
    },
    confirmationText: {
      type: String,
      default: 'CONFIRM',
    },
  },
  components: { ActionButton },
  emits: ['close', 'confirm'],
  data() {
    return {
      userInput: '',
    };
  },
  computed: {
    canConfirm() {
      return !this.requireConfirmationText || this.userInput === this.confirmationText;
    }
  },
  methods: {
    confirm() {
      if (this.canConfirm) {
        this.$emit('confirm');
      }
    },
  },
};
</script>

<style scoped>
.modal-overlay {
  position: fixed;
  inset: 0;
  background-color: rgba(11, 18, 32, 0.6);
  backdrop-filter: blur(4px);
  z-index: 200;
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 16px;
  animation: fadeIn 200ms var(--t-base) forwards;
}

@keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }

.modal-panel {
  background-color: var(--surface);
  padding: 28px 32px;
  border-radius: var(--r-lg);
  box-shadow: var(--shadow-lg);
  width: 100%;
  max-width: 480px;
  animation: popIn 250ms var(--t-base) forwards;
}

@keyframes popIn {
  from {
    opacity: 0;
    transform: scale(0.95);
  }
  to {
    opacity: 1;
    transform: scale(1);
  }
}

.modal-title {
  font-size: 20px;
  font-weight: 600;
  margin: 0 0 8px;
  color: var(--text);
}

.modal-message {
  font-size: 15px;
  color: var(--muted);
  line-height: 1.6;
  margin: 0;
}

.confirmation-area {
  margin-top: 24px;
}

.confirmation-prompt {
  font-size: 13px;
  color: var(--muted);
  margin: 0 0 8px;
}
.confirmation-prompt strong {
  color: var(--text);
  font-weight: 600;
}

.confirmation-input {
  width: 100%;
  height: 40px;
  padding: 0 12px;
  background-color: var(--surface-2);
  border: 1px solid var(--border);
  color: var(--text);
  border-radius: var(--r-sm);
  font-size: 14px;
  transition: all var(--t-fast);
}
.confirmation-input:focus {
  outline: none;
  border-color: var(--primary);
  box-shadow: 0 0 0 2px rgba(29, 78, 216, 0.2);
}

.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  margin-top: 28px;
}
</style>
