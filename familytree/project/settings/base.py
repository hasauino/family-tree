import os
from pathlib import Path

from django.utils.translation import gettext_lazy as _
from dotenv import load_dotenv

PROJECT_DIR = Path(__file__).parent.parent
BASE_DIR = PROJECT_DIR.parent

load_dotenv(BASE_DIR.parent / ".env")

SECRET_KEY = "-yp#*#01vf1+d$8^0b=7hsrfv!y#21c1a1mjmspj18)n93a)o5"

DEBUG = True
# During production set this to true; the port number will be omitted from site URL (when sent over email during account activation or password reset)
# check context_processors.py
# why this is needed?
# When Django is running behind a proxy server,
# the port is a bit hard to be found in a nice way that works for both
# during development and in production.
# Even forwarding the proxy headers won't fix, because the proxy server
# might be running behind another proxy server
IS_PRODUCTION = False

ALLOWED_HOSTS = []

INSTALLED_APPS = [
    "main.apps.MainConfig",
    "home.apps.HomeConfig",
    "wagtail_pages",
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # Wagtail ------
    "wagtail.contrib.forms",
    "wagtail.contrib.redirects",
    "wagtail.embeds",
    "wagtail.sites",
    "wagtail.users",
    "wagtail.snippets",
    "wagtail.documents",
    "wagtail.images",
    "wagtail.search",
    "wagtail.admin",
    "wagtail",
    "modelcluster",
    "taggit",
    # EndWagtail ------
    "graphene_django",
    "corsheaders",
    "pwa",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    # Must be high in the stack, before CommonMiddleware, so CORS preflight
    # (OPTIONS) requests are answered before they can be rejected as 405.
    "corsheaders.middleware.CorsMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "main.middleware.force_language_cookie",
    "django.middleware.locale.LocaleMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    # Wagtail ------
    "wagtail.contrib.legacy.sitemiddleware.SiteMiddleware",
    "wagtail.contrib.redirects.middleware.RedirectMiddleware",
    # EndWagtail ------
    "main.middleware.populate_session_defaults",
]

ROOT_URLCONF = f"{PROJECT_DIR.name}.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
                "main.context_processors.main",
            ],
        },
    },
]

WSGI_APPLICATION = f"{PROJECT_DIR.name}.wsgi.application"

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": PROJECT_DIR / os.environ.get("DATABASE", "db.sqlite3"),
    }
}

DEFAULT_AUTO_FIELD = "django.db.models.AutoField"

AUTH_PASSWORD_VALIDATORS = [
    {
        "NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.CommonPasswordValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.NumericPasswordValidator",
    },
]

SECRET_KEY = os.environ.get("SECRET_KEY", "django-insecure-7qn#kui98^3tt59e#jcdy8f_ch@y=_&66a$w11+6_zx%)#qddz")

# Time zone
TIME_ZONE = "UTC"
USE_TZ = True

# Localization
USE_I18N = True
USE_L10N = True
LANGUAGE_CODE = os.environ.get("LANGUAGE_CODE", "en")
LOCALE_PATHS = [
    BASE_DIR / "locales",
]
LANGUAGES = [
    ("ar", _("Arabic")),
    ("en", _("English")),
]
LANGUAGE_COOKIE_NAME = "language"

# Static directories
STATIC_URL = "/static/"
STATIC_ROOT = PROJECT_DIR / "static"
MEDIA_ROOT = PROJECT_DIR / "media"
MEDIA_URL = "/media/"
AUTH_USER_MODEL = "main.User"
LOGIN_REDIRECT_URL = "/"

# --- Sign-in / sign-up methods -------------------------------------------
# Every method below is independently switchable, and the mobile/web client
# discovers which ones are live through the GraphQL `authConfig` query, so a
# method only ever appears in the UI once it is both enabled *and* credentialed.
# A social provider is considered "available" only when its `*_ENABLED` flag is
# true AND its client ids / app credentials are present.


def _env_bool(name, default):
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in ("1", "true", "yes", "on")


def _env_list(name):
    """Comma-separated env var -> stripped, non-empty list (e.g. accepted OAuth audiences)."""
    return [item.strip() for item in os.environ.get(name, "").split(",") if item.strip()]


# Email + password sign-in/up.
AUTH_EMAIL_ENABLED = _env_bool("AUTH_EMAIL_ENABLED", True)
# When true, registering creates an inactive account and emails an activation
# link (the existing django-registration flow); when false the account is
# active immediately and the client is signed straight in.
AUTH_EMAIL_REQUIRE_ACTIVATION = _env_bool("AUTH_EMAIL_REQUIRE_ACTIVATION", True)

# Google: accepted token audiences (the OAuth client ids of every platform that
# may sign in — iOS, Android, web). Comma-separated.
AUTH_GOOGLE_ENABLED = _env_bool("AUTH_GOOGLE_ENABLED", False)
GOOGLE_CLIENT_IDS = _env_list("GOOGLE_CLIENT_IDS")

# Apple: accepted token audiences (the app's bundle id and/or services id).
AUTH_APPLE_ENABLED = _env_bool("AUTH_APPLE_ENABLED", False)
APPLE_CLIENT_IDS = _env_list("APPLE_CLIENT_IDS")

# Facebook: the app id/secret used to validate the access token.
AUTH_FACEBOOK_ENABLED = _env_bool("AUTH_FACEBOOK_ENABLED", False)
FACEBOOK_APP_ID = os.environ.get("FACEBOOK_APP_ID", "")
FACEBOOK_APP_SECRET = os.environ.get("FACEBOOK_APP_SECRET", "")
# Outgoing mail goes through Resend's HTTP API (see main.email_backend).
EMAIL_BACKEND = os.environ.get("EMAIL_BACKEND", "main.email_backend.ResendEmailBackend")
RESEND_API_KEY = os.environ.get("RESEND_API_KEY", "")

DOMAIN = os.environ.get("DOMAIN_NAME", "family-tree.com")

# wagtail
SITE_NAME = os.environ.get("SITE_NAME", "Family Tree")
WAGTAIL_SITE_NAME = SITE_NAME
WAGTAILADMIN_BASE_URL = DOMAIN
DEFAULT_FROM_EMAIL = os.environ.get("DEFAULT_FROM_EMAIL", "noreply@omaritree.com")

# GraphQL
GRAPHENE = {"SCHEMA": "main.graphql.schema"}

# DB backup
DB_BACKUP_DIR = PROJECT_DIR / "backups"
NUMBER_OF_BACKUPS = 30

# Push notifications (Firebase Cloud Messaging). Path to the service-account
# JSON from the Firebase console (Project settings -> Service accounts ->
# "Generate new private key"). Leave unset to disable push entirely — the app
# falls back to in-app notifications only and the test suite needs no Firebase.
FIREBASE_CREDENTIALS_FILE = os.environ.get("FIREBASE_CREDENTIALS_FILE") or None
