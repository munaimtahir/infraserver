# Health Endpoint Standard

All managed apps should expose:

- `/health`: process-level health
- `/ready`: readiness (dependencies ready)
- `/live`: liveness for restart decisions

Response contract for `/health`:

```json
{
  "status": "ok|degraded|down",
  "version": "string",
  "timestamp": "ISO-8601",
  "deps": {
    "db": "ok|down",
    "cache": "ok|down"
  }
}
```

Dashboard config should treat non-2xx and missing fields as degraded.
