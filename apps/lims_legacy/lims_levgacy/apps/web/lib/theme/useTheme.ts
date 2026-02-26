'use client';

/**
 * Optional theme hook scaffold. Admin UI uses CSS variables (--bg, --surface, --accent, etc.)
 * from lib/theme/tokens.css. This stub can later drive dark/light toggle or tenant branding.
 * No real implementation yet.
 */
export function useTheme(): { theme: 'light' | 'dark'; setTheme: (t: 'light' | 'dark') => void } {
  return {
    theme: 'light',
    setTheme: () => {},
  };
}
