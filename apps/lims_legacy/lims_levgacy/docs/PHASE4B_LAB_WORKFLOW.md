# PHASE4B_LAB_WORKFLOW
Date: 2026-02-19

## Scope
Phase 4B deepens only the LAB domain with tenant-scoped catalog management, structured per-parameter results, verification gating, and PDF-only report publishing.

## Data Model Overview
New LAB entities are tenant-scoped and normalized (no ad-hoc JSON for clinical results):
- `LabTestDefinition`: test master (`code`, `name`, `department`, `active`)
- `LabTestParameter`: analytes per test (`unit`, `refLow`, `refHigh`, `refText`, `displayOrder`)
- `LabOrderItem`: ordered test instance on encounter (`ORDERED | RESULTS_ENTERED | VERIFIED`)
- `LabResultItem`: per-parameter result value + computed flag (`LOW | HIGH | NORMAL | ABNORMAL | UNKNOWN`)

Key constraints:
- Unique test code per tenant: `(tenant_id, code)`
- One ordered test per encounter/test pair: `(tenant_id, encounter_id, test_id)`
- One parameter result per order item: `(tenant_id, order_item_id, parameter_id)`

## Endpoint Map
Catalog:
- `POST /lab/tests`
- `GET /lab/tests`
- `GET /lab/tests/{testId}`
- `POST /lab/tests/{testId}/parameters`
- `GET /lab/tests/{testId}/parameters`

LAB encounter workflow:
- `POST /encounters/{id}:lab-add-test`
- `GET /encounters/{id}/lab-tests`
- `POST /encounters/{id}:lab-enter-results`
- `POST /encounters/{id}:lab-verify`
- `POST /encounters/{id}:lab-publish`

## Verification Gating Rules
Server-enforced rules:
- LAB-only endpoints reject non-LAB encounters with `409 INVALID_ENCOUNTER_TYPE`.
- Result entry allowed only while encounter is `IN_PROGRESS`.
- Result flags are computed server-side.
- Verification allowed only when order item is `RESULTS_ENTERED` and all active parameters have values.
- Encounter finalize for LAB requires:
  - At least one ordered LAB test.
  - All LAB order items status `VERIFIED`.

If unmet, finalize returns `409 LAB_NOT_VERIFIED`.

## Publish Rules (PDF-only)
- LAB report publish endpoint is `POST /encounters/{id}:lab-publish`.
- Publish is allowed only for LAB encounters in `FINALIZED`/`DOCUMENTED`.
- Publish delegates to document pipeline with fixed `documentType = LAB_REPORT_V1`.
- Official output is PDF only (`/documents/{documentId}/file`); no HTML print route.

## Determinism Notes
`LAB_REPORT_V1` payload now includes:
- `lab.tests[]` sorted deterministically by `(department, testName, testCode)`
- `parameters[]` sorted by `(displayOrder, name)`
- stable references (`refText` or numeric range string)
- optional `verifiedSummary` from persisted DB values

Determinism guarantees:
- Payload hash from canonical JSON.
- PDF hash from rendered bytes.
- Repeated publish with unchanged canonical data returns same document identity/hash.
- No runtime `now()` timestamps are injected into payload/template.

## Troubleshooting
- `INVALID_ENCOUNTER_TYPE`: endpoint used for non-LAB encounter.
- `INVALID_STATE`: result entry/verify called outside `IN_PROGRESS`.
- `LAB_RESULTS_INCOMPLETE`: one or more active parameters are missing values.
- `LAB_NOT_VERIFIED`: finalize attempted before all ordered tests are verified.
- `DOCUMENT_NOT_RENDERED`: file download requested before rendering completed.
