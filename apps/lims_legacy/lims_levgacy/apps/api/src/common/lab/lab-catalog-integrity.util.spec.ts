import { DomainException } from '../errors/domain.exception';
import {
  ensureSingleReferenceRangeMatch,
  normalizeCatalogText,
} from './lab-catalog-integrity.util';

describe('lab catalog integrity utilities', () => {
  it('normalizes parameter identity text deterministically', () => {
    expect(normalizeCatalogText('  Serum   Albumin  ')).toBe('serum albumin');
    expect(normalizeCatalogText('  mg / dL  ')).toBe('mg / dl');
    expect(normalizeCatalogText(undefined)).toBe('');
    expect(normalizeCatalogText(null)).toBe('');
  });

  it('throws ambiguity error when multiple reference ranges match', () => {
    expect(() =>
      ensureSingleReferenceRangeMatch([
        {
          id: 'range-a',
          refLow: 1,
          refHigh: 2,
          refText: null,
        },
        {
          id: 'range-b',
          refLow: 3,
          refHigh: 4,
          refText: null,
        },
      ]),
    ).toThrow(DomainException);

    try {
      ensureSingleReferenceRangeMatch([
        {
          id: 'range-a',
          refLow: 1,
          refHigh: 2,
          refText: null,
        },
        {
          id: 'range-b',
          refLow: 3,
          refHigh: 4,
          refText: null,
        },
      ]);
      fail('expected ambiguity error');
    } catch (error) {
      expect(error).toBeInstanceOf(DomainException);
      const domainError = error as DomainException;
      expect(domainError.code).toBe('AMBIGUOUS_REFERENCE_RANGE_MATCH');
      expect(domainError.details).toEqual({
        candidate_ids: ['range-a', 'range-b'],
      });
    }
  });
});
