"""ASGI entry for App Platform: `uvicorn kfn8.api.main:app`. Not started by the agent."""
from ..db.session import make_engine, make_sessionmaker
from ..settings import get_settings
from .app import create_app
from .telemetry import RequestTelemetry

settings = get_settings()
app = RequestTelemetry(create_app(settings, make_sessionmaker(make_engine(settings.database_url))))
