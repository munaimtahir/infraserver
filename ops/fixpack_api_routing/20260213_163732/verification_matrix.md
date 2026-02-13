| Host | Path | Method | Expected | Actual | Result |
|---|---|---|---|---|---|
| portal.alshifalab.pk | / | GET | 200 | 200 | PASS |
| portal.alshifalab.pk | /api | GET | routed (redirect/ok) | 200 | PASS |
| portal.alshifalab.pk | /api/docs/ | GET | 200 | 200 | PASS |
| portal.alshifalab.pk | /api/auth/token/ | POST | non-404 auth response | 400 | PASS |
| portal.alshifalab.pk | /api/auth/token/ | OPTIONS | 200/204 preflight | 200 | PASS |
| ops.alshifalab.pk | / | GET | 200 | 200 | PASS |
| ops.alshifalab.pk | /api | GET | routed (redirect/ok) | 200 | PASS |
| ops.alshifalab.pk | /api/docs/ | GET | 200 | 200 | PASS |
| ops.alshifalab.pk | /api/auth/token/ | POST | non-404 auth response | 400 | PASS |
| ops.alshifalab.pk | /api/auth/token/ | OPTIONS | 200/204 preflight | 200 | PASS |
