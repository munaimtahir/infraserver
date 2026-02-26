/**
 * Hook for "add test to order" picker: prefers catalog tests, falls back to lab tests.
 * Backend accepts either catalog test id or lab test id for POST .../lab-add-test.
 */

import { useQuery } from '@tanstack/react-query';
import { client } from '@/lib/sdk/client';
import { parseApiError } from '@/lib/api-errors';
import { operatorKeys } from '@/lib/sdk/hooks';

export type TestOption = {
  id: string;
  code: string;
  name: string;
  section: string;
};

export function useTestsForOrder(enabled: boolean) {
  return useQuery({
    queryKey: [...operatorKeys.all, 'tests-for-order'],
    enabled,
    queryFn: async (): Promise<TestOption[]> => {
      const { data: catalogData, error: catalogError } = await client.GET(
        '/catalog/tests',
        { params: { query: { status: 'active' } } },
      );
      if (!catalogError && catalogData?.data?.length) {
        return catalogData.data.map((t) => ({
          id: t.id,
          code: t.testCode,
          name: t.testName,
          section: t.section?.trim() ?? '',
        }));
      }
      const { data: labData, error: labError } = await client.GET('/lab/tests');
      if (labError) {
        throw new Error(parseApiError(labError, 'Failed to load tests').message);
      }
      const list = labData?.data ?? [];
      return list.map((t) => ({
        id: t.id,
        code: t.code,
        name: t.name,
        section: (t.department ?? '').trim(),
      }));
    },
  });
}
