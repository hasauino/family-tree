"""GraphQL sign-in / sign-up: email+password, social providers, and registration.

Every flow ends in an ordinary Django session: the resolvers call
``django.contrib.auth.login`` on the request behind ``/graphql`` (which is
``csrf_exempt``), so ``SessionMiddleware`` sets the ``sessionid`` cookie on the
response — the same cookie the rest of the app already authenticates with. The
client therefore needs no token handling; it just keeps its cookie jar.
"""

import graphene
from django.conf import settings
from django.contrib.auth import authenticate, get_user_model
from django.contrib.auth import login as auth_login
from django.contrib.auth.password_validation import validate_password
from django.core import signing
from django.core.exceptions import ValidationError
from django.template.loader import render_to_string

from main.auth import SocialAuthError, get_or_create_social_user, verify_social_token

from . import types

User = get_user_model()

# Matches django-registration's HMAC workflow so accounts registered in-app
# activate through the very same /accounts/activate/ endpoint as the web form.
REGISTRATION_SALT = getattr(settings, "REGISTRATION_SALT", "registration")
MODEL_BACKEND = "django.contrib.auth.backends.ModelBackend"


def _current_user_payload(user):
    """The CurrentUserType shape, matching Query.resolve_me."""
    return {
        "id": user.id,
        "username": user.get_username(),
        "is_staff": user.is_staff,
        "is_authenticated": True,
    }


def google_available():
    return settings.AUTH_GOOGLE_ENABLED and bool(settings.GOOGLE_CLIENT_IDS)


def apple_available():
    return settings.AUTH_APPLE_ENABLED and bool(settings.APPLE_CLIENT_IDS)


def facebook_available():
    return settings.AUTH_FACEBOOK_ENABLED and bool(settings.FACEBOOK_APP_ID and settings.FACEBOOK_APP_SECRET)


class AuthConfigType(graphene.ObjectType):
    """Which sign-in methods the client should offer (enabled *and* configured)."""

    email_enabled = graphene.Boolean()
    google_enabled = graphene.Boolean()
    apple_enabled = graphene.Boolean()
    facebook_enabled = graphene.Boolean()
    require_activation = graphene.Boolean(
        description="Whether email sign-up needs an activation link before the account works"
    )


def resolve_auth_config(parent, info):
    return {
        "email_enabled": settings.AUTH_EMAIL_ENABLED,
        "google_enabled": google_available(),
        "apple_enabled": apple_available(),
        "facebook_enabled": facebook_available(),
        "require_activation": settings.AUTH_EMAIL_REQUIRE_ACTIVATION,
    }


class AuthReply:
    """Mutation result: ok/message plus the signed-in user (null on failure)."""

    ok = graphene.Boolean()
    message = graphene.String()
    user = graphene.Field(types.CurrentUserType)

    @staticmethod
    def success(user, message=""):
        return {"ok": True, "message": message, "user": _current_user_payload(user)}

    @staticmethod
    def fail(message=""):
        return {"ok": False, "message": message, "user": None}


class PasswordLogin(graphene.Mutation, AuthReply):
    """Sign in with an email *or* username plus password."""

    class Arguments:
        identifier = graphene.String(required=True, description="Email address or username")
        password = graphene.String(required=True)

    def mutate(root, info, identifier, password):
        if not settings.AUTH_EMAIL_ENABLED:
            return AuthReply.fail("Email sign-in is disabled")
        identifier = (identifier or "").strip()
        # Let people type either their email or their username.
        username = identifier
        if "@" in identifier:
            match = User.objects.filter(email__iexact=identifier).first()
            if match is not None:
                username = match.get_username()
        user = authenticate(info.context, username=username, password=password)
        if user is None:
            return AuthReply.fail("Invalid credentials")
        auth_login(info.context, user)
        return AuthReply.success(user)


class SocialLogin(graphene.Mutation, AuthReply):
    """Sign in with a Google / Apple / Facebook token verified server-side."""

    class Arguments:
        provider = graphene.String(required=True, description="google | apple | facebook")
        token = graphene.String(required=True, description="The provider identity/access token")
        # Apple omits the name from its token; the client may forward what the
        # SDK gave it on the first authorization so we can fill the profile in.
        first_name = graphene.String(required=False)
        last_name = graphene.String(required=False)

    def mutate(root, info, provider, token, first_name=None, last_name=None):
        provider = (provider or "").lower()
        available = {"google": google_available, "apple": apple_available, "facebook": facebook_available}
        check = available.get(provider)
        if check is None:
            return AuthReply.fail(f"Unknown sign-in provider: {provider}")
        if not check():
            return AuthReply.fail(f"{provider.title()} sign-in is not configured")
        try:
            profile = verify_social_token(provider, token)
        except SocialAuthError as exc:
            return AuthReply.fail(str(exc))
        # Backfill names the provider didn't include in the token.
        if not profile.first_name and first_name:
            profile.first_name = first_name
        if not profile.last_name and last_name:
            profile.last_name = last_name
        user = get_or_create_social_user(profile)
        if not user.is_active:
            return AuthReply.fail("This account is disabled")
        auth_login(info.context, user, backend=MODEL_BACKEND)
        return AuthReply.success(user)


def _send_activation_email(request, user):
    """Email an HMAC activation link, mirroring django-registration's workflow."""
    activation_key = signing.dumps(obj=user.get_username(), salt=REGISTRATION_SALT)
    context = {
        "scheme": "https" if request.is_secure() else "http",
        "activation_key": activation_key,
        "expiration_days": settings.ACCOUNT_ACTIVATION_DAYS,
        "user": user,
    }
    subject = "".join(
        render_to_string("django_registration/activation_email_subject.txt", context, request=request).splitlines()
    )
    body = render_to_string("django_registration/activation_email_body.txt", context, request=request)
    user.email_user(subject, body, settings.DEFAULT_FROM_EMAIL)


class RegisterEmail(graphene.Mutation, AuthReply):
    """Create an account from email + password.

    With ``AUTH_EMAIL_REQUIRE_ACTIVATION`` the account is created inactive and an
    activation link is emailed (``user`` comes back null, ``ok`` true); otherwise
    it is activated and signed in immediately.
    """

    class Arguments:
        email = graphene.String(required=True)
        password = graphene.String(required=True)
        first_name = graphene.String(required=False)
        last_name = graphene.String(required=False)

    def mutate(root, info, email, password, first_name=None, last_name=None):
        if not settings.AUTH_EMAIL_ENABLED:
            return AuthReply.fail("Email sign-up is disabled")
        email = (email or "").strip()
        if not email or "@" not in email:
            return AuthReply.fail("Enter a valid email address")
        if User.objects.filter(email__iexact=email).exists():
            return AuthReply.fail("An account with this email already exists")

        require_activation = settings.AUTH_EMAIL_REQUIRE_ACTIVATION
        user = User(
            username=_unique_username_from_email(email),
            email=email,
            first_name=(first_name or "").strip() or None,
            last_name=(last_name or "").strip() or None,
            is_active=not require_activation,
        )
        try:
            validate_password(password, user)
        except ValidationError as exc:
            return AuthReply.fail(" ".join(exc.messages))
        user.set_password(password)
        user.save()

        if require_activation:
            _send_activation_email(info.context, user)
            return {"ok": True, "message": "activation_sent", "user": None}

        auth_login(info.context, user, backend=MODEL_BACKEND)
        return AuthReply.success(user)


def _unique_username_from_email(email):
    base = email.split("@", 1)[0].strip()[:140] or "user"
    candidate = base
    suffix = 1
    while User.objects.filter(username=candidate).exists():
        suffix += 1
        candidate = f"{base}{suffix}"
    return candidate
