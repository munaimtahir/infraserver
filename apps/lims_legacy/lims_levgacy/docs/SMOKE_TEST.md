# SMOKE_TEST
Date: 2026-02-19

## Preconditions
- Stack up: `docker compose up -d --build`
- DB synced: `docker compose exec -T api npx prisma db push --schema prisma/schema.prisma --accept-data-loss`
- Tenant/domain/admin seeded (idempotent):
  - `docker compose exec -T api node prisma/seed-dev.js`
  - tenant A domain: `tenant-a.test`
  - tenant B domain: `tenant-b.test`
  - admin user: `admin@vexel.dev` / `Admin@123!`

## Login
```bash
curl -sS -X POST http://127.0.0.1:3000/auth/login \
  -H 'Host: vexel.alshifalab.pk' \
  -H 'Content-Type: application/json' \
  -d '{"email":"admin@vexel.dev","password":"Admin@123!"}'
```
Expected:
- `accessToken` present.

## Health checks
```bash
curl -sS http://127.0.0.1:3000/health
curl -sS http://127.0.0.1:5000/health
```
Expected:
- API: `{"status":"ok","service":"api"}`
- PDF: `{"status":"ok"}`

## LAB flow + LAB_REPORT_V1
Create patient + LAB encounter + workflow:
```bash
curl -sS -X POST http://127.0.0.1:3000/patients \
  -H 'Host: tenant-a.test' \
  -H 'Content-Type: application/json' \
  -d '{"name":"Smoke Patient","gender":"male"}'

curl -sS -X POST http://127.0.0.1:3000/encounters \
  -H 'Host: tenant-a.test' \
  -H 'Content-Type: application/json' \
  -d '{"patientId":"<PATIENT_ID>","type":"LAB"}'

curl -sS -X POST "http://127.0.0.1:3000/encounters/<LAB_ENCOUNTER_ID>:start-prep" -H 'Host: tenant-a.test'
curl -sS -X POST "http://127.0.0.1:3000/encounters/<LAB_ENCOUNTER_ID>:save-prep" \
  -H 'Host: tenant-a.test' \
  -H 'Content-Type: application/json' \
  -d '{"specimenType":"Blood"}'
curl -sS -X POST "http://127.0.0.1:3000/encounters/<LAB_ENCOUNTER_ID>:start-main" -H 'Host: tenant-a.test'

curl -sS -X POST "http://127.0.0.1:3000/lab/tests" \
  -H 'Host: tenant-a.test' \
  -H 'Content-Type: application/json' \
  -d '{"code":"ALB","name":"Serum Albumin","department":"Biochemistry"}'

curl -sS -X POST "http://127.0.0.1:3000/lab/tests/<TEST_ID>/parameters" \
  -H 'Host: tenant-a.test' \
  -H 'Content-Type: application/json' \
  -d '{"name":"Albumin","unit":"g/dL","refLow":3.5,"refHigh":5.0,"displayOrder":1}'

curl -sS -X POST "http://127.0.0.1:3000/encounters/<LAB_ENCOUNTER_ID>:lab-add-test" \
  -H 'Host: tenant-a.test' \
  -H 'Content-Type: application/json' \
  -d '{"testId":"<TEST_ID>"}'

curl -sS -X POST "http://127.0.0.1:3000/encounters/<LAB_ENCOUNTER_ID>:lab-enter-results" \
  -H 'Host: tenant-a.test' \
  -H 'Authorization: Bearer mock.<TENANT_ID>.<USER_ID>' \
  -H 'Content-Type: application/json' \
  -d '{"orderItemId":"<ORDER_ITEM_ID>","results":[{"parameterId":"<PARAMETER_ID>","value":"4.5"}]}'

curl -sS -X POST "http://127.0.0.1:3000/encounters/<LAB_ENCOUNTER_ID>:lab-verify" \
  -H 'Host: tenant-a.test' \
  -H 'Authorization: Bearer mock.<TENANT_ID>.<USER_ID>' \
  -H 'Content-Type: application/json' \
  -d '{"orderItemId":"<ORDER_ITEM_ID>"}'

curl -sS -X POST "http://127.0.0.1:3000/encounters/<LAB_ENCOUNTER_ID>:finalize" \
  -H 'Host: tenant-a.test'
```
Observed:
- `regNo=REG-00000001`
- `encounterCode=LAB-2026-000001`
- `PREP -> IN_PROGRESS -> FINALIZED` after verification
- `Albumin=4.5` computes flag `NORMAL`

Publish LAB report (PDF-only):
```bash
curl -sS -X POST "http://127.0.0.1:3000/encounters/<LAB_ENCOUNTER_ID>:lab-publish" \
  -H 'Host: tenant-a.test'
```
Observed:
- Returns `DocumentResponse` with `type=LAB_REPORT_V1`
- Returns `status=QUEUED|RENDERED`
- Download endpoint `/documents/<DOCUMENT_ID>/file` returns `Content-Type: application/pdf`

Idempotency check:
```bash
curl -sS -X POST "http://127.0.0.1:3000/encounters/<LAB_ENCOUNTER_ID>:lab-publish" \
  -H 'Host: tenant-a.test'
```
Observed:
- Same `documentId`, `payloadHash`, and `pdfHash`.

## RAD flow + RAD_REPORT_V1
```bash
curl -sS -X POST http://127.0.0.1:3000/encounters \
  -H 'Host: tenant-a.test' \
  -H 'Content-Type: application/json' \
  -d '{"patientId":"<PATIENT_ID>","type":"RAD"}'

curl -sS -X POST "http://127.0.0.1:3000/encounters/<RAD_ENCOUNTER_ID>:start-prep" -H 'Host: tenant-a.test'
curl -sS -X POST "http://127.0.0.1:3000/encounters/<RAD_ENCOUNTER_ID>:start-main" -H 'Host: tenant-a.test'
curl -sS -X POST "http://127.0.0.1:3000/encounters/<RAD_ENCOUNTER_ID>:save-main" \
  -H 'Host: tenant-a.test' \
  -H 'Content-Type: application/json' \
  -d '{"reportText":"No acute cardiopulmonary abnormality.","impression":"Stable chest radiograph."}'
curl -sS -X POST "http://127.0.0.1:3000/encounters/<RAD_ENCOUNTER_ID>:finalize" -H 'Host: tenant-a.test'

curl -sS -X POST "http://127.0.0.1:3000/encounters/<RAD_ENCOUNTER_ID>:document" \
  -H 'Host: tenant-a.test' \
  -H 'Content-Type: application/json' \
  -d '{"documentType":"RAD_REPORT_V1"}'
```
Observed:
- `type=RAD_REPORT_V1`
- `templateKey=RAD_REPORT_V1`
- Download endpoint returns `Content-Type: application/pdf`.

## OPD flow + OPD_SUMMARY_V1
```bash
curl -sS -X POST http://127.0.0.1:3000/encounters \
  -H 'Host: tenant-a.test' \
  -H 'Content-Type: application/json' \
  -d '{"patientId":"<PATIENT_ID>","type":"OPD"}'

curl -sS -X POST "http://127.0.0.1:3000/encounters/<OPD_ENCOUNTER_ID>:start-prep" -H 'Host: tenant-a.test'
curl -sS -X POST "http://127.0.0.1:3000/encounters/<OPD_ENCOUNTER_ID>:start-main" -H 'Host: tenant-a.test'
curl -sS -X POST "http://127.0.0.1:3000/encounters/<OPD_ENCOUNTER_ID>:save-main" \
  -H 'Host: tenant-a.test' \
  -H 'Content-Type: application/json' \
  -d '{"chiefComplaint":"Headache","assessment":"Tension headache","plan":"Hydration and rest"}'
curl -sS -X POST "http://127.0.0.1:3000/encounters/<OPD_ENCOUNTER_ID>:finalize" -H 'Host: tenant-a.test'

curl -sS -X POST "http://127.0.0.1:3000/encounters/<OPD_ENCOUNTER_ID>:document" \
  -H 'Host: tenant-a.test' \
  -H 'Content-Type: application/json' \
  -d '{"documentType":"OPD_SUMMARY_V1"}'
```
Observed:
- `type=OPD_SUMMARY_V1`
- `templateKey=OPD_SUMMARY_V1`

## Tenant isolation check
```bash
curl -sS -o /tmp/tenant-b-doc.json -w '%{http_code}' \
  "http://127.0.0.1:3000/documents/<DOCUMENT_ID>/file" \
  -H 'Host: tenant-b.test'
```
Observed:
- HTTP `404`
