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
from django.core.exceptions import ValidationError
from django.template.loader import render_to_string

from main.auth import SocialAuthError, get_or_create_social_user, verify_social_token
from main.models import EmailVerification

from . import types

User = get_user_model()

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


def _email_code(request, user, code, template):
    """Email a 6-digit ``code`` using the ``account/<template>_{subject,body}.txt`` pair."""
    context = {"code": code, "user": user, "minutes": EmailVerification.TTL.seconds // 60}
    subject = "".join(render_to_string(f"account/{template}_subject.txt", context, request=request).splitlines())
    body = render_to_string(f"account/{template}_body.txt", context, request=request)
    user.email_user(subject, body, settings.DEFAULT_FROM_EMAIL)


def _user_for_email(email, *, is_active):
    """The account for ``email`` in the given active state, or None."""
    email = (email or "").strip()
    if not email:
        return None
    return User.objects.filter(email__iexact=email, is_active=is_active).first()


def _check_code(verification, code):
    """Validate ``code`` against a verification row, counting a failed attempt.

    Returns None on success, else an error message: ``code_expired`` /
    ``too_many_attempts`` / ``code_invalid``.
    """
    if verification.is_expired:
        return "code_expired"
    if verification.attempts >= EmailVerification.MAX_ATTEMPTS:
        return "too_many_attempts"
    if not verification.matches(code):
        verification.attempts += 1
        verification.save(update_fields=["attempts"])
        return "too_many_attempts" if verification.attempts >= EmailVerification.MAX_ATTEMPTS else "code_invalid"
    return None


class VerifyEmailCode(graphene.Mutation, AuthReply):
    """Confirm a new account with the emailed 6-digit code and sign the user in.

    Failure messages: ``code_expired``, ``too_many_attempts``, ``code_invalid``.
    """

    class Arguments:
        email = graphene.String(required=True)
        code = graphene.String(required=True)

    def mutate(root, info, email, code):
        if not settings.AUTH_EMAIL_ENABLED:
            return AuthReply.fail("Email sign-up is disabled")
        user = _user_for_email(email, is_active=False)
        verification = EmailVerification.active_for(user, EmailVerification.ACTIVATION) if user else None
        if verification is None:
            return AuthReply.fail("code_invalid")
        error = _check_code(verification, code)
        if error:
            return AuthReply.fail(error)
        user.is_active = True
        user.save(update_fields=["is_active"])
        verification.delete()
        auth_login(info.context, user, backend=MODEL_BACKEND)
        return AuthReply.success(user)


class ResendCode(graphene.Mutation, AuthReply):
    """Re-issue and email a fresh verification code, honouring a resend cooldown.

    To avoid leaking which emails are registered, an unknown/active email also
    reports ``ok`` (without sending). ``resend_too_soon`` is returned while the
    cooldown is still active.
    """

    class Arguments:
        email = graphene.String(required=True)

    def mutate(root, info, email):
        if not settings.AUTH_EMAIL_ENABLED:
            return AuthReply.fail("Email sign-up is disabled")
        user = _user_for_email(email, is_active=False)
        if user is None:
            return {"ok": True, "message": "code_sent", "user": None}
        existing = EmailVerification.active_for(user, EmailVerification.ACTIVATION)
        if existing is not None and existing.seconds_until_resend > 0:
            return AuthReply.fail("resend_too_soon")
        code = EmailVerification.issue_for(user, EmailVerification.ACTIVATION)
        _email_code(info.context, user, code, "verification_email")
        return {"ok": True, "message": "code_sent", "user": None}


class RequestPasswordReset(graphene.Mutation, AuthReply):
    """Email a password-reset code (this is both the initial request and resend).

    Always reports ``ok`` for an unknown/inactive email so it can't be used to
    probe which addresses are registered. ``resend_too_soon`` while the cooldown
    is still active.
    """

    class Arguments:
        email = graphene.String(required=True)

    def mutate(root, info, email):
        if not settings.AUTH_EMAIL_ENABLED:
            return AuthReply.fail("Email sign-in is disabled")
        user = _user_for_email(email, is_active=True)
        if user is None:
            return {"ok": True, "message": "code_sent", "user": None}
        existing = EmailVerification.active_for(user, EmailVerification.PASSWORD_RESET)
        if existing is not None and existing.seconds_until_resend > 0:
            return AuthReply.fail("resend_too_soon")
        code = EmailVerification.issue_for(user, EmailVerification.PASSWORD_RESET)
        _email_code(info.context, user, code, "password_reset_email")
        return {"ok": True, "message": "code_sent", "user": None}


class ResetPassword(graphene.Mutation, AuthReply):
    """Verify the emailed code, set a new password, and sign the user in.

    A weak new password is rejected *without* consuming the code, so the user
    can retry with the same code. Failure messages: ``code_expired`` /
    ``too_many_attempts`` / ``code_invalid``, or the password-validation reason.
    """

    class Arguments:
        email = graphene.String(required=True)
        code = graphene.String(required=True)
        new_password = graphene.String(required=True)

    def mutate(root, info, email, code, new_password):
        if not settings.AUTH_EMAIL_ENABLED:
            return AuthReply.fail("Email sign-in is disabled")
        user = _user_for_email(email, is_active=True)
        verification = EmailVerification.active_for(user, EmailVerification.PASSWORD_RESET) if user else None
        if verification is None:
            return AuthReply.fail("code_invalid")
        error = _check_code(verification, code)
        if error:
            return AuthReply.fail(error)
        try:
            validate_password(new_password, user)
        except ValidationError as exc:
            return AuthReply.fail(" ".join(exc.messages))
        user.set_password(new_password)
        user.save(update_fields=["password"])
        verification.delete()
        auth_login(info.context, user, backend=MODEL_BACKEND)
        return AuthReply.success(user)


class RegisterEmail(graphene.Mutation, AuthReply):
    """Create an account from email + password.

    With ``AUTH_EMAIL_REQUIRE_ACTIVATION`` the account is created inactive and a
    6-digit verification code is emailed (``user`` comes back null, ``ok`` true,
    ``message`` ``code_sent``); the client then calls ``verifyEmailCode``.
    Otherwise the account is active and signed in immediately.
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
            code = EmailVerification.issue_for(user, EmailVerification.ACTIVATION)
            _email_code(info.context, user, code, "verification_email")
            return {"ok": True, "message": "code_sent", "user": None}

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
