# UI scaffold: Operator (LIMS) pages

**Date:** 2026-02-19  
**Scope:** Page scaffolds only; no deep business logic. Contract-first, SDK-only, multi-tenant safe.

## Routes created

| Route | Description |
|-------|-------------|
| `/operator/register` | Registration: patient + encounter (LAB) form; submit → SDK create patient + create encounter; success → redirect to worklist detail |
| `/operator/worklist` | Worklist: table of LAB encounters (Reg #, Patient, Visit/Encounter, Status, Updated, Actions) |
| `/operator/worklist/[encounterId]` | Worklist detail: identity header + status pill + placeholder sections |
| `/operator/samples` | Samples list: table of LAB encounters (TODO: filter by sample state when contract supports) |
| `/operator/samples/[encounterId]` | Samples detail: identity + placeholder "Sample collection / receiving controls" |
| `/operator/verify` | Verification queue: table from `/lab/verification-queue` |
| `/operator/verify/[encounterId]` | Verify detail: identity + "Verification checklist" placeholder; Publish Report button wired to `POST /encounters/{id}:lab-publish` |
| `/operator/reports/published` | Published reports list (client-side filter on LAB encounters with `labEncounterStatus === 'PUBLISHED'` or `status === 'DOCUMENTED'`) |
| `/operator/reports/published/[encounterId]` | Published report detail: identity + PDF download placeholder (wired: lab-publish then GET document file) |

Shared layout: `/operator` layout with left nav (Register, Worklist, Samples, Verify, Published Reports) and top bar placeholder (Tenant · User).

## SDK endpoints used

| Endpoint | Used on |
|----------|---------|
| `GET /patients` | (Register: not used for search in scaffold; list patients could be added) |
| `POST /patients` | Register page |
| `POST /encounters` | Register page (after patient create) |
| `GET /encounters` | Worklist, Samples, Published reports (with `type: 'LAB'`) |
| `GET /encounters/{id}` | All detail pages |
| `GET /patients/{id}` | All detail pages (for identity header) |
| `GET /lab/verification-queue` | Verify list page |
| `POST /encounters/{id}:lab-verify` | Verify detail (per order item; scaffold has TODO for bulk) |
| `POST /encounters/{id}:lab-publish` | Verify detail (Publish Report), Published report detail (to obtain document before download) |
| `GET /documents/{documentId}/file` | Published report detail (download PDF) |

## TODOs / missing contract or backend

1. **Worklist / Samples / Published list – patient name and Reg #**  
   `GET /encounters` returns `Encounter[]` with `patientId` but no expanded patient. So Reg # and Patient columns show "—". Options: backend expand (e.g. `?expand=patient`) or a batch-patient endpoint; or accept N+1 for now for scaffold.

2. **Samples list filter**  
   No contract filter for "encounters requiring sample action" or "sample not received". Currently all LAB encounters are shown; TODO: add query param when backend supports it.

3. **Published reports list**  
   No dedicated "published reports" list endpoint. Scaffold uses `GET /encounters?type=LAB` and filters client-side by `labEncounterStatus === 'PUBLISHED'` or `status === 'DOCUMENTED'`. TODO: add e.g. `GET /lab/reports/published` or `status=DOCUMENTED` in list encounters.

4. **Search on worklist**  
   Search input is present; `listEncounters` has `patientId`, `type`, `status`, `page` but no free-text search. TODO: backend search by patient name/Reg # or pass-through query param.

5. **Verify detail – "Mark Verified"**  
   Verification is per order item via `POST /encounters/{id}:lab-verify` with `orderItemId`. Scaffold has a disabled "Mark Verified" button with TODO; "Publish Report" is wired.

6. **Report metadata (report time, signatories)**  
   Placeholder only; add when contract exposes these on document or encounter.

## Files added/updated

- `apps/web/app/operator/layout.tsx`
- `apps/web/app/operator/register/page.tsx`
- `apps/web/app/operator/worklist/page.tsx`
- `apps/web/app/operator/worklist/[encounterId]/page.tsx`
- `apps/web/app/operator/samples/page.tsx`
- `apps/web/app/operator/samples/[encounterId]/page.tsx`
- `apps/web/app/operator/verify/page.tsx`
- `apps/web/app/operator/verify/[encounterId]/page.tsx`
- `apps/web/app/operator/reports/published/page.tsx`
- `apps/web/app/operator/reports/published/[encounterId]/page.tsx`
- `apps/web/components/operator/OperatorNav.tsx`
- `apps/web/components/operator/StatusPill.tsx`
- `apps/web/components/operator/WorklistTable.tsx`
- `apps/web/components/operator/EncounterHeader.tsx`
- `apps/web/lib/operator/routes.ts`
- `apps/web/lib/workflow/mapStatus.ts`
- `apps/web/lib/sdk/client.ts`
- `apps/web/lib/sdk/hooks.ts`
- Root nav: link to Operator (`/operator/worklist`) in `apps/web/app/layout.tsx`

## Status display

- Backend source of truth: `labEncounterStatus` (on Encounter) or `derived_encounter_status` (on verification queue item).
- `lib/workflow/mapStatus.ts` maps to normalized display enum and pill variant (DRAFT, ORDERED, RECEIVED, RESULTS_ENTERED, VERIFIED, PUBLISHED). Input remains backend value; UI only maps labels/colors.

## Build

`npm run build --workspace=web` passes. A workaround was applied in `app/encounters/[encounterId]/page.tsx` for the billing GET (generated `PathsWithMethod` omits `/encounters/{id}/billing`); BillingResponse is typed as `RecordPaymentResponse | null` and the billing call uses a typed escape so the SDK is still used at runtime.

## Quality

- All API calls via `@vexel/contracts` client (re-exported from `lib/api` and `lib/sdk/client`). No ad-hoc `fetch` to backend.
- Types from generated schema (`paths['/...']`). No UI-inferred workflow state.
- No tenant ID in URL; auth/session context only.
- Empty and loading states on list/detail pages; errors shown when SDK calls fail.
