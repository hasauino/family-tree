import os
from pathlib import Path

from django.utils.translation import gettext_lazy as _

PROJECT_DIR = Path(__file__).parent.parent
BASE_DIR = PROJECT_DIR.parent

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
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
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

DEFAULT_AUTO_FIELD = 'django.db.models.AutoField'

AUTH_PASSWORD_VALIDATORS = [
    {
        "NAME":
        "django.contrib.auth.password_validation.UserAttributeSimilarityValidator",
    },
    {
        "NAME":
        "django.contrib.auth.password_validation.MinimumLengthValidator",
    },
    {
        "NAME":
        "django.contrib.auth.password_validation.CommonPasswordValidator",
    },
    {
        "NAME":
        "django.contrib.auth.password_validation.NumericPasswordValidator",
    },
]

SECRET_KEY = os.environ.get(
    "SECRET_KEY",
    "django-insecure-7qn#kui98^3tt59e#jcdy8f_ch@y=_&66a$w11+6_zx%)#qddz")

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

# django registration
ACCOUNT_ACTIVATION_DAYS = 2
REGISTRATION_OPEN = True
AUTH_USER_MODEL = "main.User"
LOGIN_REDIRECT_URL = "/"
EMAIL_USE_TLS = os.environ.get("EMAIL_USE_TLS") == "True"
EMAIL_PORT = int(os.environ.get("EMAIL_PORT", 587))
EMAIL_HOST = os.environ.get("EMAIL_HOST", "mail.gmx.net")
EMAIL_HOST_USER = os.environ.get("EMAIL_HOST_USER")
EMAIL_HOST_PASSWORD = os.environ.get("EMAIL_HOST_PASSWORD")

DOMAIN = os.environ.get("DOMAIN_NAME", "family-tree.com")

# wagtail
SITE_NAME = os.environ.get("SITE_NAME", "Family Tree")
WAGTAIL_SITE_NAME = SITE_NAME
WAGTAILADMIN_BASE_URL = DOMAIN
DEFAULT_FROM_EMAIL = EMAIL_HOST_USER

# GraphQL
GRAPHENE = {
    "SCHEMA": "main.graphql.schema"
}

# DB backup
DB_BACKUP_DIR = PROJECT_DIR / "backups"
NUMBER_OF_BACKUPS = 30