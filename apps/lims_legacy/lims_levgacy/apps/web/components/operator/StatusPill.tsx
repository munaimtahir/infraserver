'use client';

import { mapLabStatus, type StatusDisplay } from '@/lib/workflow/mapStatus';

type StatusPillProps = {
  /** Backend status (e.g. labEncounterStatus, derived_encounter_status). */
  status: string | null | undefined;
};

const variantClasses: Record<StatusDisplay['variant'], string> = {
  gray: 'bg-gray-100 text-gray-800',
  blue: 'bg-blue-100 text-blue-800',
  amber: 'bg-amber-100 text-amber-800',
  green: 'bg-green-100 text-green-800',
  emerald: 'bg-emerald-100 text-emerald-800',
  purple: 'bg-purple-100 text-purple-800',
};

export function StatusPill({ status }: StatusPillProps) {
  const { display } = mapLabStatus(status);
  return (
    <span
      className={`inline-flex items-center rounded-full px-3 py-1 text-xs font-medium ${variantClasses[display.variant]}`}
    >
      {display.label}
    </span>
  );
}
