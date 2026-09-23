# Kfn8 backend (component of the kfn8 monorepo)

Anonymous read-only catalogue API, asset contract v1 and private operator ingestion. Python 3.12, FastAPI, SQLAlchemy 2 async, Alembic, PostgreSQL; published bytes are served from Spaces CDN, never proxied.

## Setup

```sh
cd _Kfn8-frontend-avp/_Kfn8-backend-fastapi
python3.12 -m venv venv && venv/bin/pip install -r requirements.txt
```

## Tests (no long-running services)

```sh
venv/bin/python -m pytest -q          # starts and removes a throwaway Postgres cluster for the session
venv/bin/python tools/export_openapi.py --check
venv/bin/python tools/generate_swift_client.py --check
venv/bin/kfn8-validate assets-conformed/*/manifest.json
```

## Layout

- `contracts/v1/` — `asset.schema.json`, `ASSET-CONTRACT.md`, pinned `openapi.json` (backend-owned; the Swift client is generated from it).
- `src/kfn8/contract/` — geometry measurement and the validator (`kfn8-validate`, `--bundle` for client bundles).
- `src/kfn8/api/` — API v1, signed cursors, redacted request telemetry; `main.py` is the ASGI entry for App Platform.
- `src/kfn8/db/` — models, sessions, throwaway Postgres helper for tests.
- `src/kfn8/ingest/` — storage (local / Spaces), staged pipeline, constrained converters, `kfn8-ingest` CLI.
- `alembic/` — 0001 schema, 0002 tenant seed.
- `tools/` — Blender conform/inspect, manifest generation, batch dry run, OpenAPI export, Swift generator.
- `assets-source/` (private sources), `assets-conformed/` (conformed renditions + manifests), `ledger/` (licence evidence, validation and batch reports).
- `ops/` — App Platform spec and the operations runbook (costs, provisioning, billing alert, operator workflow, smoke test).

## Running the API locally (you run it; the agent never starts servers)

```sh
export KFN8_DATABASE_URL=postgresql+asyncpg://localhost/kfn8
venv/bin/alembic -x url=$KFN8_DATABASE_URL upgrade head
venv/bin/uvicorn kfn8.api.main:app --reload
```
