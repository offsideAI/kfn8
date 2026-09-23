"""Runtime configuration from environment. No secrets have defaults; nothing here is committed with real values."""
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


def normalize_database_url(url: str) -> str:
    """Accept the connection string exactly as DigitalOcean shows it (postgresql://…?sslmode=require) and convert it for
    SQLAlchemy's asyncpg driver, which needs the +asyncpg scheme and `ssl=` instead of libpq's `sslmode=`."""
    parts = urlsplit(url)
    scheme = parts.scheme
    if scheme in ("postgres", "postgresql"):
        scheme = "postgresql+asyncpg"
    query = []
    for k, v in parse_qsl(parts.query):
        if k == "sslmode":
            query.append(("ssl", v))
        else:
            query.append((k, v))
    return urlunsplit((scheme, parts.netloc, parts.path, urlencode(query), parts.fragment))


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="KFN8_", env_file=".env", extra="ignore")

    database_url: str = "postgresql+asyncpg://localhost/kfn8"
    cdn_base_url: str = "https://cdn.invalid"
    cursor_secret: str = "dev-only-cursor-secret-change-me"
    page_default: int = 30
    page_max: int = 100
    # Private operator storage (sources, review, rejected) and public published storage are separate buckets.
    spaces_endpoint: str = "https://nyc3.digitaloceanspaces.com"
    spaces_region: str = "nyc3"
    private_bucket: str = "kfn8-private"
    public_bucket: str = "kfn8-public"
    spaces_key: str | None = None
    spaces_secret: str | None = None
    cdn_purge_token: str | None = None
    cdn_endpoint_id: str | None = None


    @field_validator("database_url")
    @classmethod
    def _normalize(cls, v: str) -> str:
        return normalize_database_url(v)


def get_settings() -> Settings:
    return Settings()
