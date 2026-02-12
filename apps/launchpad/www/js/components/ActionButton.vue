<template>
  <button
    :class="buttonClasses"
    :disabled="disabled || isLoading"
    :type="type"
  >
    <span v-if="isLoading" class="spinner"></span>
    <span class="btn-text"><slot></slot></span>
  </button>
</template>

<script>
export default {
  name: 'ActionButton',
  props: {
    variant: { type: String, default: 'primary' }, // primary, outline, ghost, danger
    size: { type: String, default: 'md' }, // md, sm
    disabled: Boolean,
    isLoading: Boolean,
    type: { type: String, default: 'button' },
  },
  computed: {
    buttonClasses() {
      return ['action-btn', this.variant, this.size, { 'is-loading': this.isLoading }];
    }
  }
};
</script>
