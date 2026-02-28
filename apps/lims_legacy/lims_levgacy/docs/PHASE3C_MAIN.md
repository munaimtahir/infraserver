# PHASE3C_MAIN
Date: 2026-02-18

## Scope
Phase 3C introduces typed MAIN data per encounter type and enforces finalize invariants through command endpoints.

Implemented endpoints:
- `POST /encounters/{id}:save-main`
- `GET /encounters/{id}/main`
- Existing `POST /encounters/{id}:finalize` now validates MAIN requirements.

## Data model
Tenant-scoped tables keyed by `(tenant_id, encounter_id)`:
- `LabEncounterMain`
- `RadEncounterMain`
- `OpdEncounterMain`
- `BbEncounterMain`
- `IpdEncounterMain`

Each table has:
- `id`, `tenant_id`, `encounter_id`
- typed service fields
- `created_at`, `updated_at`
- unique `(tenant_id, encounter_id)` and per-encounter uniqueness.

## Workflow rules
- MAIN save allowed only when encounter status is `IN_PROGRESS`.
- Finalize transition remains command-only (`POST /encounters/{id}:finalize`).
- Finalize gating (MVP):
  - `RAD`: `reportText` is required.
  - `BB`: when `crossmatchResult=COMPATIBLE` and issuance is signaled, `componentIssued` and positive `unitsIssued` are required.
  - `LAB`, `OPD`, `IPD`: no required MAIN fields in MVP.
- Errors use standardized envelope:
  - `INVALID_STATE` when saving MAIN outside `IN_PROGRESS`.
  - `MAIN_INCOMPLETE` when finalize gating fails.

## Web behavior
Encounter detail page now supports:
- Typed MAIN form when status is `IN_PROGRESS`.
- Save MAIN via `:save-main`.
- Finalize via `:finalize`.
- Read-only MAIN display outside edit state.
- For `FINALIZED`/`DOCUMENTED`: document actions (`:document`, refresh status, download PDF).

## Test coverage
Updated e2e coverage includes:
- Save-main invalid state rejection (`PREP` -> `409 INVALID_STATE`).
- RAD happy path: `start-main` -> `save-main(reportText)` -> `finalize` -> `:document` -> PDF download.
- Tenant isolation: tenant B cannot read tenant A MAIN (`GET /encounters/{id}/main` -> `404`).

## Notes
- OpenAPI remains the source of truth; contracts were regenerated after updates.
- Document pipeline from Phase 3A is reused unchanged for finalize-to-document behavior.
