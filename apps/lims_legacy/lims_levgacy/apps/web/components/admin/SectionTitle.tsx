type SectionTitleProps = {
  title: string;
  subtitle?: string;
};

export function SectionTitle({ title, subtitle }: SectionTitleProps) {
  return (
    <div className="mb-3">
      <h3 className="text-sm font-semibold uppercase tracking-wide text-[var(--muted)]">{title}</h3>
      {subtitle ? <p className="mt-1 text-sm text-[var(--muted)]">{subtitle}</p> : null}
    </div>
  );
}
