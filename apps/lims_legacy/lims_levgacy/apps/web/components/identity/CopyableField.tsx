'use client';

import { useState, useCallback } from 'react';

export type CopyableFieldSize = 'sm' | 'md' | 'lg';

type CopyableFieldProps = {
    label: string;
    value: string;
    copyValue?: string;
    size?: CopyableFieldSize;
};

const sizeClasses: Record<CopyableFieldSize, { label: string; value: string }> = {
    sm: { label: 'text-xs text-gray-500', value: 'text-sm' },
    md: { label: 'text-sm text-gray-600', value: 'text-base' },
    lg: { label: 'text-sm font-medium text-gray-700', value: 'text-xl font-semibold text-gray-900' },
};

export function CopyableField({ label, value, copyValue, size = 'md' }: CopyableFieldProps) {
    const [feedback, setFeedback] = useState<'idle' | 'success' | 'error'>('idle');
    const toCopy = (copyValue ?? value).trim() || value;

    const handleCopy = useCallback(async () => {
        if (!toCopy) {
            setFeedback('error');
            return;
        }
        try {
            await navigator.clipboard.writeText(toCopy);
            setFeedback('success');
        } catch {
            setFeedback('error');
        }
        const t = setTimeout(() => setFeedback('idle'), 2000);
        return () => clearTimeout(t);
    }, [toCopy]);

    const displayValue = (value || '—').trim() || '—';
    const canCopy = toCopy.length > 0;

    return (
        <div className="flex flex-wrap items-baseline gap-2">
            <span className={sizeClasses[size].label}>{label}</span>
            <span className={sizeClasses[size].value}>{displayValue}</span>
            {canCopy && (
                <>
                    <button
                        type="button"
                        onClick={() => void handleCopy()}
                        className="rounded border border-gray-300 bg-gray-50 px-2 py-1 text-xs font-medium text-gray-700 hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-gray-400"
                        aria-label={`Copy ${label}`}
                    >
                        Copy
                    </button>
                    {feedback === 'success' && (
                        <span className="text-xs text-green-600">Copied</span>
                    )}
                    {feedback === 'error' && (
                        <span className="text-xs text-red-600">Copy failed</span>
                    )}
                </>
            )}
        </div>
    );
}
