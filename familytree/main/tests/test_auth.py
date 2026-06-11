"""Tests for the GraphQL sign-in / sign-up flows (main/graphql/auth.py)."""

import re
from datetime import timedelta

import pytest
from django.contrib.auth.models import AnonymousUser
from django.contrib.sessions.middleware import SessionMiddleware
from django.test import RequestFactory
from django.utils import timezone

from main.auth.users import get_or_create_social_user
from main.auth.verifiers import SocialAuthError, SocialProfile
from main.graphql import auth
from main.models import EmailVerification, User


def make_request():
    """A POST request with a real session so auth_login can attach a sessionid."""
    request = RequestFactory().post("/graphql")
    SessionMiddleware(lambda r: None).process_request(request)
    request.user = AnonymousUser()
    return request


def info_for(request):
    from types import SimpleNamespace

    return SimpleNamespace(context=request)


def _code_from_email(body):
    """Pull the 6-digit verification code out of the emailed message body."""
    return re.search(r"\b(\d{6})\b", body).group(1)


# ---------------------------------------------------------------------------
# auth_config
# ---------------------------------------------------------------------------


def test_auth_config_reflects_settings(settings):
    settings.AUTH_EMAIL_ENABLED = True
    settings.AUTH_GOOGLE_ENABLED = True
    settings.GOOGLE_CLIENT_IDS = ["client-1"]
    settings.AUTH_APPLE_ENABLED = True
    settings.APPLE_CLIENT_IDS = []  # enabled but not configured -> unavailable
    settings.AUTH_FACEBOOK_ENABLED = False
    settings.AUTH_EMAIL_REQUIRE_ACTIVATION = True

    cfg = auth.resolve_auth_config(None, None)
    assert cfg == {
        "email_enabled": True,
        "google_enabled": True,
        "apple_enabled": False,
        "facebook_enabled": False,
        "require_activation": True,
    }


# ---------------------------------------------------------------------------
# password_login
# ---------------------------------------------------------------------------


def test_password_login_by_username(normal_user):
    request = make_request()
    result = auth.PasswordLogin.mutate(None, info_for(request), identifier="normal", password="pw")
    assert result["ok"] is True
    assert result["user"]["username"] == "normal"
    assert request.session.session_key is not None


def test_password_login_by_email(normal_user):
    request = make_request()
    result = auth.PasswordLogin.mutate(None, info_for(request), identifier="normal@example.com", password="pw")
    assert result["ok"] is True
    assert result["user"]["username"] == "normal"


def test_password_login_bad_credentials(normal_user):
    request = make_request()
    result = auth.PasswordLogin.mutate(None, info_for(request), identifier="normal", password="wrong")
    assert result["ok"] is False
    assert result["user"] is None


def test_password_login_disabled(settings, normal_user):
    settings.AUTH_EMAIL_ENABLED = False
    request = make_request()
    result = auth.PasswordLogin.mutate(None, info_for(request), identifier="normal", password="pw")
    assert result["ok"] is False


# ---------------------------------------------------------------------------
# register_email
# ---------------------------------------------------------------------------


def test_register_email_sends_code(settings, db, mailoutbox):
    settings.AUTH_EMAIL_REQUIRE_ACTIVATION = True
    request = make_request()
    result = auth.RegisterEmail.mutate(None, info_for(request), email="newbie@example.com", password="s3curePass!42")
    assert result["ok"] is True
    assert result["message"] == "code_sent"
    assert result["user"] is None  # not signed in until verified
    user = User.objects.get(email="newbie@example.com")
    assert user.is_active is False
    # A verification code exists for the new account and was emailed.
    assert EmailVerification.objects.filter(user=user).exists()
    assert len(mailoutbox) == 1
    assert re.search(r"\b\d{6}\b", mailoutbox[0].body)


def test_register_email_instant_signin(settings, db):
    settings.AUTH_EMAIL_REQUIRE_ACTIVATION = False
    request = make_request()
    result = auth.RegisterEmail.mutate(None, info_for(request), email="instant@example.com", password="s3curePass!42")
    assert result["ok"] is True
    assert result["user"]["username"]
    assert User.objects.get(email="instant@example.com").is_active is True
    assert request.session.session_key is not None


def test_register_email_rejects_duplicate(settings, normal_user):
    request = make_request()
    result = auth.RegisterEmail.mutate(None, info_for(request), email="normal@example.com", password="s3curePass!42")
    assert result["ok"] is False


def test_register_email_rejects_weak_password(settings, db):
    request = make_request()
    result = auth.RegisterEmail.mutate(None, info_for(request), email="weak@example.com", password="123")
    assert result["ok"] is False
    assert not User.objects.filter(email="weak@example.com").exists()


# ---------------------------------------------------------------------------
# verify_email_code / resend_code
# ---------------------------------------------------------------------------


def _register_and_get_code(mailoutbox, settings, email="verify-me@example.com"):
    settings.AUTH_EMAIL_REQUIRE_ACTIVATION = True
    auth.RegisterEmail.mutate(None, info_for(make_request()), email=email, password="s3curePass!42")
    return email, _code_from_email(mailoutbox[0].body)


def _activation_row(user):
    return EmailVerification.active_for(user, EmailVerification.ACTIVATION)


def test_verify_email_code_activates_and_signs_in(settings, db, mailoutbox):
    email, code = _register_and_get_code(mailoutbox, settings)
    user = User.objects.get(email=email)
    assert user.is_active is False

    request = make_request()
    result = auth.VerifyEmailCode.mutate(None, info_for(request), email=email, code=code)
    assert result["ok"] is True
    assert result["user"]["username"] == user.get_username()
    user.refresh_from_db()
    assert user.is_active is True
    assert request.session.session_key is not None  # signed in
    # The code is single-use: it's gone once consumed.
    assert not EmailVerification.objects.filter(user=user).exists()


def test_verify_email_code_rejects_wrong_code_and_counts_attempts(settings, db, mailoutbox):
    email, code = _register_and_get_code(mailoutbox, settings)
    wrong = "000000" if code != "000000" else "111111"

    result = auth.VerifyEmailCode.mutate(None, info_for(make_request()), email=email, code=wrong)
    assert result["ok"] is False
    assert result["message"] == "code_invalid"
    user = User.objects.get(email=email)
    assert user.is_active is False
    assert _activation_row(user).attempts == 1


def test_verify_email_code_locks_out_after_max_attempts(settings, db, mailoutbox):
    email, code = _register_and_get_code(mailoutbox, settings)
    user = User.objects.get(email=email)
    # Burn all but one attempt, then the final wrong try trips the lock-out.
    row = _activation_row(user)
    row.attempts = EmailVerification.MAX_ATTEMPTS - 1
    row.save(update_fields=["attempts"])

    result = auth.VerifyEmailCode.mutate(None, info_for(make_request()), email=email, code="999999")
    assert result["message"] == "too_many_attempts"
    # Even the correct code is now refused until a new one is issued.
    blocked = auth.VerifyEmailCode.mutate(None, info_for(make_request()), email=email, code=code)
    assert blocked["message"] == "too_many_attempts"


def test_verify_email_code_rejects_expired(settings, db, mailoutbox):
    email, code = _register_and_get_code(mailoutbox, settings)
    user = User.objects.get(email=email)
    ev = _activation_row(user)
    ev.created_at = timezone.now() - EmailVerification.TTL - timedelta(seconds=1)
    ev.save(update_fields=["created_at"])

    result = auth.VerifyEmailCode.mutate(None, info_for(make_request()), email=email, code=code)
    assert result["message"] == "code_expired"


def test_verify_email_code_unknown_email(db):
    result = auth.VerifyEmailCode.mutate(None, info_for(make_request()), email="ghost@example.com", code="123456")
    assert result["ok"] is False
    assert result["message"] == "code_invalid"


def test_resend_code_issues_a_fresh_code(settings, db, mailoutbox):
    email, first_code = _register_and_get_code(mailoutbox, settings)
    user = User.objects.get(email=email)
    # Move past the resend cooldown.
    ev = _activation_row(user)
    ev.created_at = timezone.now() - EmailVerification.RESEND_COOLDOWN - timedelta(seconds=1)
    ev.save(update_fields=["created_at"])

    result = auth.ResendCode.mutate(None, info_for(make_request()), email=email)
    assert result["ok"] is True
    assert len(mailoutbox) == 2
    new_code = _code_from_email(mailoutbox[1].body)
    # The new code verifies; attempts were reset.
    verified = auth.VerifyEmailCode.mutate(None, info_for(make_request()), email=email, code=new_code)
    assert verified["ok"] is True


def test_resend_code_honors_cooldown(settings, db, mailoutbox):
    email, _ = _register_and_get_code(mailoutbox, settings)
    # The just-registered code is within the cooldown window.
    result = auth.ResendCode.mutate(None, info_for(make_request()), email=email)
    assert result["ok"] is False
    assert result["message"] == "resend_too_soon"
    assert len(mailoutbox) == 1  # no second email


def test_resend_code_unknown_email_reports_ok_without_sending(db, mailoutbox):
    # Don't leak which emails are registered: unknown email still reports ok.
    result = auth.ResendCode.mutate(None, info_for(make_request()), email="ghost@example.com")
    assert result["ok"] is True
    assert len(mailoutbox) == 0


# ---------------------------------------------------------------------------
# request_password_reset / reset_password
# ---------------------------------------------------------------------------


def _request_reset_code(mailoutbox, user):
    auth.RequestPasswordReset.mutate(None, info_for(make_request()), email=user.email)
    return _code_from_email(mailoutbox[-1].body)


def test_request_password_reset_emails_a_code(normal_user, mailoutbox):
    result = auth.RequestPasswordReset.mutate(None, info_for(make_request()), email=normal_user.email)
    assert result["ok"] is True
    assert len(mailoutbox) == 1
    assert re.search(r"\b\d{6}\b", mailoutbox[0].body)
    assert EmailVerification.active_for(normal_user, EmailVerification.PASSWORD_RESET) is not None


def test_request_password_reset_unknown_email_reports_ok_without_sending(db, mailoutbox):
    result = auth.RequestPasswordReset.mutate(None, info_for(make_request()), email="ghost@example.com")
    assert result["ok"] is True
    assert len(mailoutbox) == 0


def test_request_password_reset_honors_cooldown(normal_user, mailoutbox):
    auth.RequestPasswordReset.mutate(None, info_for(make_request()), email=normal_user.email)
    again = auth.RequestPasswordReset.mutate(None, info_for(make_request()), email=normal_user.email)
    assert again["message"] == "resend_too_soon"
    assert len(mailoutbox) == 1


def test_reset_password_sets_new_password_and_signs_in(normal_user, mailoutbox):
    code = _request_reset_code(mailoutbox, normal_user)
    request = make_request()
    result = auth.ResetPassword.mutate(
        None, info_for(request), email=normal_user.email, code=code, new_password="BrandNew!pass77"
    )
    assert result["ok"] is True
    assert request.session.session_key is not None  # signed in
    normal_user.refresh_from_db()
    assert normal_user.check_password("BrandNew!pass77")
    # The reset code is single-use.
    assert EmailVerification.active_for(normal_user, EmailVerification.PASSWORD_RESET) is None


def test_reset_password_rejects_wrong_code(normal_user, mailoutbox):
    code = _request_reset_code(mailoutbox, normal_user)
    wrong = "000000" if code != "000000" else "111111"
    result = auth.ResetPassword.mutate(
        None, info_for(make_request()), email=normal_user.email, code=wrong, new_password="BrandNew!pass77"
    )
    assert result["message"] == "code_invalid"
    normal_user.refresh_from_db()
    assert not normal_user.check_password("BrandNew!pass77")


def test_reset_password_rejects_weak_password_without_consuming_code(normal_user, mailoutbox):
    code = _request_reset_code(mailoutbox, normal_user)
    result = auth.ResetPassword.mutate(
        None, info_for(make_request()), email=normal_user.email, code=code, new_password="123"
    )
    assert result["ok"] is False
    # The code survives so the user can retry with a stronger password.
    assert EmailVerification.active_for(normal_user, EmailVerification.PASSWORD_RESET) is not None
    retry = auth.ResetPassword.mutate(
        None, info_for(make_request()), email=normal_user.email, code=code, new_password="BrandNew!pass77"
    )
    assert retry["ok"] is True


# ---------------------------------------------------------------------------
# social_login
# ---------------------------------------------------------------------------


@pytest.fixture
def google_enabled(settings):
    settings.AUTH_GOOGLE_ENABLED = True
    settings.GOOGLE_CLIENT_IDS = ["test-client"]
    return settings


def test_social_login_creates_and_signs_in(google_enabled, db, monkeypatch):
    monkeypatch.setattr(
        auth,
        "verify_social_token",
        lambda provider, token: SocialProfile(
            provider="google", sub="g-123", email="g@example.com", first_name="Gee", last_name="Mail"
        ),
    )
    request = make_request()
    result = auth.SocialLogin.mutate(None, info_for(request), provider="google", token="tok")
    assert result["ok"] is True
    assert result["user"]["username"]
    user = User.objects.get(email="g@example.com")
    assert user.has_usable_password() is False
    assert request.session.session_key is not None


def test_social_login_links_existing_by_email(google_enabled, normal_user, monkeypatch):
    monkeypatch.setattr(
        auth,
        "verify_social_token",
        lambda provider, token: SocialProfile(provider="google", sub="g-9", email="normal@example.com"),
    )
    request = make_request()
    result = auth.SocialLogin.mutate(None, info_for(request), provider="google", token="tok")
    assert result["ok"] is True
    assert result["user"]["username"] == "normal"
    assert User.objects.filter(email="normal@example.com").count() == 1


def test_social_login_rejects_bad_token(google_enabled, db, monkeypatch):
    def boom(provider, token):
        raise SocialAuthError("bad token")

    monkeypatch.setattr(auth, "verify_social_token", boom)
    request = make_request()
    result = auth.SocialLogin.mutate(None, info_for(request), provider="google", token="tok")
    assert result["ok"] is False
    assert "bad token" in result["message"]


def test_social_login_unconfigured_provider(settings, db):
    settings.AUTH_APPLE_ENABLED = False
    request = make_request()
    result = auth.SocialLogin.mutate(None, info_for(request), provider="apple", token="tok")
    assert result["ok"] is False
    assert "not configured" in result["message"]


def test_social_login_unknown_provider(db):
    request = make_request()
    result = auth.SocialLogin.mutate(None, info_for(request), provider="myspace", token="tok")
    assert result["ok"] is False


# ---------------------------------------------------------------------------
# get_or_create_social_user
# ---------------------------------------------------------------------------


def test_social_user_without_email_keys_on_provider_sub(db):
    profile = SocialProfile(provider="apple", sub="a-1", email=None)
    first = get_or_create_social_user(profile)
    second = get_or_create_social_user(profile)
    assert first.pk == second.pk
    assert first.username == "apple_a-1"
