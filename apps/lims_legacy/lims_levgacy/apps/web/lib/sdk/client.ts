/**
 * SDK client for API calls. Uses generated @vexel/contracts client with auth.
 * Auth token and tenant are injected via lib/api middleware (localStorage).
 */

import { client } from '@/lib/api';

export { client };
