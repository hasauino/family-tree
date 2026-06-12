"""Turn a verified social profile into a local Django user.

Social accounts are linked by email when the provider gives us one (so signing
in with Google and later with Apple under the same address reaches the same
account). When no email is available — Apple lets users hide it, Facebook may
withhold it — we fall back to a deterministic ``{provider}_{sub}`` username so
the same provider identity always maps to the same user.
"""

from django.contrib.auth import get_user_model
from django.db import transaction

from .verifiers import SocialProfile


def _unique_username(base: str) -> str:
    """A username derived from ``base`` that does not yet exist (deduped with a suffix)."""
    User = get_user_model()
    candidate = base = (base or "user").strip()[:140] or "user"
    suffix = 1
    while User.objects.filter(username=candidate).exists():
        suffix += 1
        candidate = f"{base}{suffix}"
    return candidate


def get_or_create_social_user(profile: SocialProfile):
    """Find the user this verified profile belongs to, creating one if needed."""
    User = get_user_model()
    email = (profile.email or "").strip() or None

    with transaction.atomic():
        if email:
            existing = User.objects.filter(email__iexact=email).first()
            if existing is not None:
                return existing
            base_username = email.split("@", 1)[0]
        else:
            # No email from the provider: key on the provider's stable subject id.
            base_username = f"{profile.provider}_{profile.sub}"
            existing = User.objects.filter(username=base_username).first()
            if existing is not None:
                return existing

        user = User(
            username=_unique_username(base_username),
            email=email,
            first_name=profile.first_name or None,
            last_name=profile.last_name or None,
            is_active=True,
        )
        # Social users authenticate through the provider, never a local password.
        user.set_unusable_password()
        user.save()
        return user
