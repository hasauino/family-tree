from .pwa import *  # noqa: F403

SECRET_KEY = "-yp#*#01vf1+d$8^0b=7hsrfv!y#21c1a1mjmspj18)n93a)o5"

DEBUG = False
IS_PRODUCTION = True

ALLOWED_HOSTS = [DOMAIN, "localhost", "127.0.0.1"]

CSRF_TRUSTED_ORIGINS = [f"https://{DOMAIN}", f"http://{DOMAIN}"]

# The Flutter web app is served from a different domain (FRONTEND_URL), so it
# needs to call the GraphQL API cross-site. Allow that origin to send
# credentialed requests, and trust it for CSRF/cookies.
FRONTEND_URL = os.environ.get("FRONTEND_URL")
if FRONTEND_URL:
    CORS_ALLOWED_ORIGINS = [FRONTEND_URL]
    CORS_ALLOW_CREDENTIALS = True
    CSRF_TRUSTED_ORIGINS.append(FRONTEND_URL)

    SESSION_COOKIE_SAMESITE = "None"
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SAMESITE = "None"
    CSRF_COOKIE_SECURE = True

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {
        "logfile": {
            "class": "logging.FileHandler",
            "filename": "django.log",
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
