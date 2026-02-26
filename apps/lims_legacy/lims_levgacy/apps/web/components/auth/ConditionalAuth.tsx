'use client';

import { usePathname } from 'next/navigation';
import { AuthGuard } from './AuthGuard';

/** Paths that do not require authentication. */
const PUBLIC_PATHS = ['/', '/auth/login'] as const;

function isPublicPath(pathname: string | null): boolean {
    if (!pathname) return true;
    if (PUBLIC_PATHS.includes(pathname as (typeof PUBLIC_PATHS)[number])) return true;
    if (pathname.startsWith('/auth/')) return true;
    return false;
}

/**
 * Wraps the app: protects all routes except public paths.
 * Unauthenticated users hitting a protected path are redirected to login.
 */
export function ConditionalAuth({ children }: { children: React.ReactNode }) {
    const pathname = usePathname();

    if (isPublicPath(pathname)) {
        return <>{children}</>;
    }

    return <AuthGuard>{children}</AuthGuard>;
}
