'use client';

import { useEffect, useState } from 'react';
import { useRouter, usePathname } from 'next/navigation';

const TOKEN_KEY = 'vexel_token';

/**
 * Client-side guard: redirects to login if no auth token.
 * Call only for routes that require authentication.
 */
export function AuthGuard({ children }: { children: React.ReactNode }) {
    const router = useRouter();
    const pathname = usePathname();
    const [allowed, setAllowed] = useState(false);

    useEffect(() => {
        if (typeof window === 'undefined') return;
        const token = localStorage.getItem(TOKEN_KEY);
        if (!token) {
            const returnUrl = encodeURIComponent(pathname ?? '/');
            router.replace(`/auth/login?returnUrl=${returnUrl}`);
            return;
        }
        setAllowed(true);
    }, [pathname, router]);

    if (!allowed) {
        return (
            <div className="flex min-h-screen items-center justify-center">
                <p className="text-gray-500">Checking authentication...</p>
            </div>
        );
    }

    return <>{children}</>;
}
