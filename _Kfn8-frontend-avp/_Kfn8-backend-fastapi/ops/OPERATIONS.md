# Kfn8 backend operations (MVP1)

Nothing in this document has been executed by the agent. Provisioning, credentials and spend are founder actions.

## Baseline cost estimate (re-verify at provisioning; prices checked 2026-09-19)

| Item | Tier | Estimate / month |
|---|---|---|
| App Platform | 1 × `apps-s-1vcpu-0.5gb`, fixed, no autoscaling | US$5 |
| Managed PostgreSQL | smallest single node, no replicas | ≈ US$15 |
| Spaces + CDN | base subscription (250 GiB storage, 1 TiB egress included) | US$5 |
| **Total baseline** | | **≈ US$25** |

Variable costs: Spaces storage beyond the allowance (masters + LODs + every retained revision), CDN/origin egress beyond the allowance, API transfer, database storage growth. Library bytes are estimated from the actual manifests (`sum(size_bytes)` across renditions); downloads ≈ testers × new rendition bytes × refreshes. Public URLs allow third-party egress; watch the operational volume, not users.

Billing alert: set at 125 % of the estimated total (initially US$31.25) under Billing → Billing alerts. Notification only; never automatic shutdown. Record the confirmation in the M2 report.

Limitations: no HA, no replicas, no tested database restore. Managed backups existing is not evidence of a successful restore.

## Provisioning (founder)

1. Create the Managed PostgreSQL cluster (smallest single node) and database `kfn8`.
2. Create two Spaces buckets: `kfn8-private` (private ACL) and `kfn8-public` (public-read objects only via publish). Enable the CDN on `kfn8-public`; note the endpoint ID.
3. Create Spaces access keys and a DigitalOcean API token scoped for CDN cache purge.
4. Edit `ops/app.yaml` placeholders, then `doctl apps create --spec ops/app.yaml`. The database URL can be pasted exactly as DigitalOcean shows it.
5. Set the billing alert (above).

## Operator environment (local shell only; never committed)

```sh
export KFN8_DATABASE_URL=postgresql+asyncpg://…
export KFN8_SPACES_KEY=… KFN8_SPACES_SECRET=…
export KFN8_CDN_PURGE_TOKEN=… KFN8_CDN_ENDPOINT_ID=…
export KFN8_CDN_BASE_URL=https://<bucket>.<region>.cdn.digitaloceanspaces.com
```

## Operator workflow

```sh
kfn8-ingest register assets-conformed/<slug>/manifest.json            # prints the revision id
kfn8-ingest run <revision-id> assets-conformed/<slug>/manifest.json    # stops at "awaiting approvals"
kfn8-ingest approve <revision-id> <manifest> --kind provenance --actor "<name>" --evidence <file>
kfn8-ingest approve <revision-id> <manifest> --kind visual_dimensions --actor "<name>" --evidence <file>
kfn8-ingest run <revision-id> <manifest>                               # publishes; safe to re-run
kfn8-ingest status <revision-id>
kfn8-ingest revoke <revision-id>                                       # rights removal; re-run until state=revoked
kfn8-ingest delist <asset-id> [--market US]                            # commercial only; geometry stays
```

Any stage failure prints its report; fix the input, then re-run. Changed inputs require a new revision (immutable). Add `--local-storage DIR` for a dry run without Spaces.

## Smoke test after deploy (founder)

```sh
curl -s https://<app>/health/ready
curl -s "https://<app>/v1/assets?limit=5" | python3 -m json.tool
curl -sI "<a rendition url from /v1/assets/{id}/revisions/{n}>"   # expect 200 from the CDN, cache headers immutable
```

Local S3-compatible or filesystem tests do not prove CDN behaviour; this smoke test is the CDN evidence.
