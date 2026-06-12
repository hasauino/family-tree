from .dev import *  # noqa: F403

# Hashing passwords with the default algorithm is slow by design;
# use a fast hasher to keep the test suite quick.
PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]

EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"
