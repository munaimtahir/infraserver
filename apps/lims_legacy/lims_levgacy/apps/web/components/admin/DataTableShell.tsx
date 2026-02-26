import type { ReactNode } from 'react';
import { AdminCard } from './AdminCard';

type DataTableShellProps = {
  title: string;
  subtitle?: string;
  toolbar?: ReactNode;
  children?: ReactNode;
  isEmpty?: boolean;
  emptyTitle?: string;
  emptyDescription?: string;
};

export function DataTableShell({
  title,
  subtitle,
  toolbar,
  children,
  isEmpty,
  emptyTitle = 'No records available',
  emptyDescription = 'This area will populate after data is available.',
}: DataTableShellProps) {
  return (
    <AdminCard title={title} subtitle={subtitle}>
      {toolbar ? <div className="mb-4 flex flex-wrap items-center justify-between gap-3">{toolbar}</div> : null}
      {isEmpty ? (
        <div className="rounded-xl border border-dashed border-[var(--border)] bg-[var(--bg)] px-6 py-10 text-center">
          <p className="text-sm font-medium text-[var(--text)]">{emptyTitle}</p>
          <p className="mt-1 text-sm text-[var(--muted)]">{emptyDescription}</p>
        </div>
      ) : (
        <div className="overflow-x-auto rounded-xl border border-[var(--border)]">{children}</div>
      )}
    </AdminCard>
  );
}
