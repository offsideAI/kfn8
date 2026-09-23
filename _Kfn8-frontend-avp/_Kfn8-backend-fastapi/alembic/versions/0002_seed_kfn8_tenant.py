"""Seed the single Kfn8 tenant and its generic catalogue (MVP1 has no other tenants and no membership tables).

Revision ID: 0002
Revises: 0001
"""
from alembic import op

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None

TENANT = "00000000-0000-4000-8000-00000000c0de"
CATALOGUE = "00000000-0000-4000-8000-0000000c0a70"


def upgrade() -> None:
    op.execute(f"INSERT INTO tenant (id, name) VALUES ('{TENANT}', 'Kfn8')")
    op.execute(f"INSERT INTO catalogue (id, tenant_id, slug, name) VALUES ('{CATALOGUE}', '{TENANT}', 'kfn8-generics', 'Kfn8 generics')")


def downgrade() -> None:
    op.execute(f"DELETE FROM catalogue WHERE id = '{CATALOGUE}'")
    op.execute(f"DELETE FROM tenant WHERE id = '{TENANT}'")
