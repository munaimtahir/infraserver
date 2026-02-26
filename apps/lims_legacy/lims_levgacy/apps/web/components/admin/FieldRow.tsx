import type { ReactNode } from 'react';

type FieldRowProps = {
  label: string;
  value: ReactNode;
};

export function FieldRow({ label, value }: FieldRowProps) {
  return (
    <div className="grid grid-cols-1 gap-1 py-3 sm:grid-cols-[220px_1fr] sm:gap-4">
      <dt className="text-sm font-medium text-[var(--muted)]">{label}</dt>
      <dd className="text-sm text-[var(--text)]">{value}</dd>
    </div>
  );
}
