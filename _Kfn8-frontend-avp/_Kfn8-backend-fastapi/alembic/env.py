"""Async Alembic environment. URL comes from KFN8_DATABASE_URL or the -x url=... argument."""
import asyncio
import os

from alembic import context
from sqlalchemy.ext.asyncio import create_async_engine

from kfn8.db.models import Base
from kfn8.settings import normalize_database_url

target_metadata = Base.metadata


def _url() -> str:
    return normalize_database_url(context.get_x_argument(as_dictionary=True).get("url") or os.environ["KFN8_DATABASE_URL"])


def _run(connection):
    context.configure(connection=connection, target_metadata=target_metadata, compare_type=True)
    with context.begin_transaction():
        context.run_migrations()


async def _online():
    engine = create_async_engine(_url())
    async with engine.connect() as conn:
        await conn.run_sync(_run)
    await engine.dispose()


if context.is_offline_mode():
    context.configure(url=_url(), target_metadata=target_metadata, literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()
else:
    asyncio.run(_online())
