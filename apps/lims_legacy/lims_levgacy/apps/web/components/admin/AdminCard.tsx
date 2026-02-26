import type { ReactNode } from 'react';

type AdminCardProps = {
  title?: string;
  subtitle?: string;
  headerAction?: ReactNode;
  children: ReactNode;
  className?: string;
};

export function AdminCard({ title, subtitle, headerAction, children, className }: AdminCardProps) {
  return (
    <section
      className={`rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-6 shadow-[0_8px_24px_rgba(16,24,40,0.06)] ${
        className ?? ''
      }`}
    >
      {title || subtitle || headerAction ? (
        <div className="mb-4 flex items-start justify-between gap-4">
          <div>
            {title ? <h2 className="text-base font-semibold text-[var(--text)]">{title}</h2> : null}
            {subtitle ? <p className="mt-1 text-sm text-[var(--muted)]">{subtitle}</p> : null}
          </div>
          {headerAction ? <div>{headerAction}</div> : null}
        </div>
      ) : null}
      {children}
    </section>
  );
}
