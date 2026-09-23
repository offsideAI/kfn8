from kfn8.settings import Settings, normalize_database_url


def test_digitalocean_url_is_accepted_as_shown():
    raw = "postgresql://doadmin:pw@db-host.ondigitalocean.com:25060/kfn8?sslmode=require"
    assert normalize_database_url(raw) == "postgresql+asyncpg://doadmin:pw@db-host.ondigitalocean.com:25060/kfn8?ssl=require"
    assert Settings(database_url=raw).database_url.startswith("postgresql+asyncpg://")


def test_already_async_url_unchanged():
    url = "postgresql+asyncpg://kfn8@127.0.0.1:5432/kfn8"
    assert normalize_database_url(url) == url
