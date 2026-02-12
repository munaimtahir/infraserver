# DR Restore Drill Checklist

- [ ] Select target run ID from `/runs`
- [ ] Execute validate-only restore
- [ ] Export restore bundle for clean server test
- [ ] Bring up staging host
- [ ] Restore files/caddy to staging
- [ ] Restore DB to empty staging DB
- [ ] Verify app health endpoints (`/health`, `/ready`, `/live`)
- [ ] Verify dashboard status and critical workflows
- [ ] Record RTO/RPO and issues
- [ ] Sign-off and archive drill report

## PASS criteria
- [ ] No checksum mismatches
- [ ] Restic check passes
- [ ] All selected apps return healthy status
- [ ] Caddy routes load expected upstreams

## FAIL criteria
- [ ] Missing snapshot/artifact
- [ ] DB restore rejected due to non-empty schema
- [ ] Health checks fail after restore
- [ ] Integrity validation fails
