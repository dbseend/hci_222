# Production Refactoring Backlog

This document records the refactoring scope completed before the first
production deployment. Priorities reflect security and data-integrity risk,
not implementation effort.

## High — release blockers

| ID | Area | Before | After | Status |
|---|---|---|---|---|
| H1 | Auth and ownership | Clients supplied owner IDs and server writes used a privileged Supabase client without verified identity. | Flutter obtains an anonymous Supabase access token; FastAPI verifies the JWT and derives ownership exclusively from `sub`. RLS and grants deny direct client table writes. | Done |
| H2 | Upload and input boundaries | Multipart files and numeric/string payloads were accepted with weak bounds; unknown detections could mutate the product master. | Image type, signature, decode, dimensions, and byte size are validated. API models constrain text, coordinates, prices, units, and page size. Unknown products return 422 and cannot create catalog rows. | Done |
| H3 | Async and error handling | Synchronous model/SDK calls could block the event loop and raw dependency errors could leak to clients. | Blocking inference and Supabase calls run in a thread pool, inference is serialized, domain errors use centralized handlers, and internal details are logged but not returned. | Done |
| H4 | Production fail-closed behavior | Mock detection and local/demo data could silently mask missing infrastructure. | Production rejects mock mode, detector warm-up failure aborts startup, local data fallback is disabled, and Flutter demo fallback is explicit and off by default. | Done |

## Medium — scale and maintainability

| ID | Area | Before | After | Status |
|---|---|---|---|---|
| M1 | Supabase reliability | Upload and insert were not compensating; history signed URLs were created one by one; feed size was unbounded. | Failed inserts delete uploaded objects, signed URLs are batched, feed limits are bounded, errors are normalized, and public/signed URL failures are observable. | Done |
| M2 | Catalog and database performance | An unbounded process-lifetime cache and incomplete indexes/grants made stale data and scans likely. | Catalog cache is lock-protected with configurable TTL. Owner/time indexes and server-only grants are defined in the hardening migration. | Done |
| M3 | Flutter state and rebuilds | Community filtering/sorting and purchase submission lived inside widgets; duplicate taps and misleading local-only success paths were possible. | Cubits own community and submission state, submissions are idempotent per in-flight action, repositories are injectable, validation is centralized, and fake/dead final-screen submission state was removed. | Done |

## Low — consistency and delivery hygiene

| ID | Area | Before | After | Status |
|---|---|---|---|---|
| L1 | Configuration | Region values and demo behavior were scattered or implicit. | Region, cache TTL, upload limits, environment, and demo fallback use named environment settings generated into Flutter where appropriate. | Done |
| L2 | Diagnostics and duplication | Some Flutter catches were silent and an unused user-ID service/dependency remained. | Recoverable failures are logged or surfaced through callbacks, generic UI messages avoid leaking internals, and dead identity/submission code was removed. | Done |
| L3 | Reproducibility | Runtime, dev, and ML dependencies were mixed and no clean-environment gate existed. | Direct dependencies are pinned by role, the production container installs ML dependencies explicitly, and CI checks Python, Flutter formatting/analyze/tests, and ML tests. | Done |
| L4 | Operations documentation | Setup described mock data as the normal state and omitted fail-closed deployment requirements. | READMEs now distinguish local demo from production and document keys, RLS, model artifact, CORS, and verification requirements. | Done |

## Required deployment gates

Code completion does not apply infrastructure changes automatically. Before
production traffic is enabled:

1. Enable anonymous sign-in in Supabase Auth.
2. Apply `backend/supabase/scan_history_cache.sql` followed by
   `backend/supabase/auth_ownership_hardening.sql` to the target project.
3. Provide `backend/models/best.pt` in the deployment image or artifact mount.
4. Set real `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, and the backend-only
   `SUPABASE_SERVICE_ROLE_KEY`.
5. Set an explicit HTTPS API URL and exact `TRUEPRICE_CORS_ALLOW_ORIGINS`.
6. Keep `TRUEPRICE_APP_ENV=production`, mock/demo/local fallbacks disabled, and
   detector warm-up enabled.
7. Run the CI suite and a physical-device camera smoke test against staging.

## Next production iteration

The following items are intentionally outside this debt-removal pass and should
be scheduled before broad public launch:

- edge/API-gateway rate limiting and abuse protection;
- community moderation, cursor pagination, and retention policy;
- metrics, tracing, structured request IDs, and alerting;
- account upgrade/linking plus secure token storage for persistent accounts;
- model registry/versioning, confidence monitoring, and rollback automation;
- secret-manager injection and automated migration promotion per environment.
