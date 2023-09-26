from .base import *  # noqa: F403

SECRET_KEY = "-yp#*#01vf1+d$8^0b=7hsrfv!y#21c1a1mjmspj18)n93a)o5"

DEBUG = False

ALLOWED_HOSTS = [DOMAIN]

CSRF_TRUSTED_ORIGINS = [f"https://{DOMAIN}", f"http://{DOMAIN}"]

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
