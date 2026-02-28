/**
 * Normalizes backend lab/encounter status for UI display (labels, colors).
 * Source of truth remains backend (e.g. labEncounterStatus, derived_encounter_status).
 * UI only maps to display enum and styling.
 */

export type NormalizedLabStatus =
  | 'DRAFT'
  | 'ORDERED'
  | 'RECEIVED'
  | 'RESULTS_ENTERED'
  | 'VERIFIED'
  | 'PUBLISHED';

export type StatusDisplay = {
  label: string;
  variant: 'gray' | 'blue' | 'amber' | 'green' | 'emerald' | 'purple';
};

const DISPLAY_MAP: Record<NormalizedLabStatus, StatusDisplay> = {
  DRAFT: { label: 'Draft', variant: 'gray' },
  ORDERED: { label: 'Ordered', variant: 'blue' },
  RECEIVED: { label: 'Received', variant: 'amber' },
  RESULTS_ENTERED: { label: 'Results entered', variant: 'amber' },
  VERIFIED: { label: 'Verified', variant: 'green' },
  PUBLISHED: { label: 'Published', variant: 'emerald' },
};

/** Backend lab encounter status (contract enum). */
const BACKEND_LAB_STATUS = [
  'DRAFT',
  'ORDERED',
  'RESULTS_ENTERED',
  'VERIFIED',
  'PUBLISHED',
] as const;

/**
 * Map backend lab encounter status to normalized status and display.
 * Pass-through: if value is unknown, label is raw string and variant is gray.
 */
export function mapLabStatus(
  value: string | null | undefined
): { normalized: NormalizedLabStatus | null; display: StatusDisplay } {
  if (value == null || value === '') {
    return { normalized: null, display: { label: '—', variant: 'gray' } };
  }
  const upper = String(value).toUpperCase();
  const isKnown =
    BACKEND_LAB_STATUS.includes(upper as (typeof BACKEND_LAB_STATUS)[number]) ||
    upper === 'RECEIVED';
  const normalized: NormalizedLabStatus | null = isKnown
    ? (upper as NormalizedLabStatus)
    : null;
  const display: StatusDisplay =
    normalized && normalized in DISPLAY_MAP
      ? DISPLAY_MAP[normalized]
      : { label: value, variant: 'gray' };
  return { normalized, display };
}
