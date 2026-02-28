# Phase 4C LAB Hardening

Date: 2026-02-19

## Scope
- RBAC centralization for LAB write commands.
- LAB command idempotency/concurrency hardening.
- Domain error precision upgrades.
- Document publish tenancy and concurrency verification.
- Audit completeness for LAB commands.
- Catalog integrity guards.

## Permissions and Endpoint Mapping
- `LAB_CATALOG_WRITE`
  - `POST /lab/tests`
  - `POST /lab/tests/{testId}/parameters`
- `LAB_ORDER_WRITE`
  - `POST /encounters/{id}:lab-add-test`
- `LAB_RESULTS_WRITE`
  - `POST /encounters/{id}:lab-enter-results`
- `LAB_RESULTS_VERIFY`
  - `POST /encounters/{id}:lab-verify`
- `LAB_REPORT_PUBLISH`
  - `POST /encounters/{id}:lab-publish`

## Error Codes (Confirmed/New)
- `LAB_ORDER_EMPTY`
  - Encounter finalize blocked because no LAB orders exist.
- `LAB_RESULTS_INCOMPLETE`
  - Includes `details.missing[]` with parameter metadata.
- `LAB_ALREADY_VERIFIED`
  - Includes `details.verified_by` and `details.verified_at`.
- `ENCOUNTER_FINALIZE_BLOCKED_UNVERIFIED_LAB`
  - Includes `details.unverified_order_items[]`.
- `LAB_PUBLISH_BLOCKED_NOT_FINALIZED`
  - Includes `details.current_status`.
- `AMBIGUOUS_REFERENCE_RANGE_MATCH`
  - Includes `details.candidate_ids[]`.

## Idempotency and Concurrency Behavior
- Enter results:
  - Deterministic upsert by `(tenantId, orderItemId, parameterId)` prevents duplicates.
  - Repeated request with same idempotency key is stable and non-duplicating.
- Verify results:
  - Repeating verify by same actor returns success (idempotent).
  - Repeating verify by different actor returns `409` with `LAB_ALREADY_VERIFIED`.
  - Status transition uses conditional update for race safety.
- Publish report:
  - Document reuse is keyed by deterministic payload hash and tenant encounter scope.
  - Failed-document reset uses conditional update to avoid concurrent reset races.
  - Queue enqueue remains single-job-per-document (`jobId=tenantId__documentId`).
  - Publish response includes `status` and supports `QUEUED` then `RENDERED` progression.

## Tenancy Boundary
- Document metadata and file retrieval remain tenant-scoped by `(tenantId, documentId)`.
- LAB publish remains tenant-scoped by `(tenantId, encounterId)`.
- Added E2E negative case for tenant-B publish attempt on tenant-A encounter.

## Audit Coverage
- Commands now emit persisted audit events:
  - `lims.order.created`
  - `lims.results.entered`
  - `lims.results.verified`
  - `lims.report.publish.requested`
- Blocked command attempts emit failure audit events with:
  - `failure_reason_code`
  - `failure_reason_details`
- Command payload includes:
  - `tenant_id`, `user_id`, `encounter_id`, `order_id`
  - `idempotency_key`, `correlation_id`
  - `prev_status`, `next_status`

## Smoke Steps
1. Create LAB test and parameter with a token containing `LAB_CATALOG_WRITE`.
2. Add test to encounter with `LAB_ORDER_WRITE`.
3. Enter results twice with same idempotency key and confirm no duplicate values.
4. Verify twice with same actor (success), then verify with different actor (`409 LAB_ALREADY_VERIFIED`).
5. Finalize and publish LAB report twice; confirm same document id/hash.
6. Use tenant-B host to access tenant-A document/publish endpoint and confirm denial (`404` or `403`).

## Evidence
- Run artifacts: `DEPLOY_RUNS/phase4c_lab_hardening_20260219_080718`

