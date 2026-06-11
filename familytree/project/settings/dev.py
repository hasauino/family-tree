from .pwa import *  # noqa: F403

ALLOWED_HOSTS = ["*"]
DEBUG = True
CSRF_TRUSTED_ORIGINS = [f"http://localhost:{os.environ.get('PORT', '8000')}"]

# In development, print emails (with the activation link) to the runserver
# console instead of sending them, so sign-up can be tested without Resend or a
# verified domain. Set EMAIL_BACKEND in the environment to send for real.
EMAIL_BACKEND = os.environ.get("EMAIL_BACKEND", "django.core.mail.backends.console.EmailBackend")

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
