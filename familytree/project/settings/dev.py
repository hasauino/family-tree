from .pwa import *  # noqa: F403

ALLOWED_HOSTS = ["*"]
DEBUG = True
CSRF_TRUSTED_ORIGINS = [f"http://localhost:{os.environ.get('PORT', '8000')}"]

# Allow the Flutter web app (served from a different localhost port) to call the
# GraphQL API in development. Restrict this with CORS_ALLOWED_ORIGINS in prod.
CORS_ALLOW_ALL_ORIGINS = True

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
        },
    },
    "root": {
        "handlers": ["console"],
        "level": "DEBUG",
    },
}
