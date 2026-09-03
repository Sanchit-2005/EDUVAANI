# PALASH-AI — IndicTrans2 Translation Service
# Exposes the FastAPI application when used as a package.
try:
    from .app import app
    __all__ = ["app"]
except ImportError:
    pass
