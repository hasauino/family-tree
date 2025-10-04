from .pwa import *  # noqa: F403

ALLOWED_HOSTS = ["*"]
DEBUG = True
CSRF_TRUSTED_ORIGINS = [f"http://localhost:{os.environ.get('PORT', '8000')}"]

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