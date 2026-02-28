'use client';

import { IdentityHeader } from '@/components/identity/IdentityHeader';
import type { IdentityHeaderProps } from '@/lib/identity/mapIdentity';
import { StatusPill } from './StatusPill';

type EncounterHeaderProps = IdentityHeaderProps & {
  /** Backend status (e.g. labEncounterStatus). */
  status?: string | null;
};

export function EncounterHeader({ status, ...identityProps }: EncounterHeaderProps) {
  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <IdentityHeader {...identityProps} />
        {status != null && status !== '' && (
          <div className="flex items-center gap-2">
            <span className="text-sm font-medium text-gray-600">Status</span>
            <StatusPill status={status} />
          </div>
        )}
      </div>
    </div>
  );
}
