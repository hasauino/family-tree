import os

from .base import *  # noqa: F403

DEBUG = False

ALLOWED_HOSTS = ["localhost"]

CSRF_TRUSTED_ORIGINS = [f"http://localhost:{os.environ.get('PORT', '9000')}"]

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {
        "logfile": {
            "class": "logging.FileHandler",
            'filename': 'django.log',
        },
    },
    "loggers": {
        "django": {
            "handlers": ["logfile"],
            "level": "DEBUG",
            "propagate": False,
        },
    },
}
