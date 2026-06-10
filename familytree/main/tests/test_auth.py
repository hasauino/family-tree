"""Tests for the GraphQL sign-in / sign-up flows (main/graphql/auth.py)."""

import pytest
from django.contrib.auth.models import AnonymousUser
from django.contrib.sessions.middleware import SessionMiddleware
from django.core import signing
from django.test import RequestFactory

from main.auth.users import get_or_create_social_user
from main.auth.verifiers import SocialAuthError, SocialProfile
from main.graphql import auth
from main.models import User


def make_request():
    """A POST request with a real session so auth_login can attach a sessionid."""
    request = RequestFactory().post("/graphql")
    SessionMiddleware(lambda r: None).process_request(request)
    request.user = AnonymousUser()
    return request


def info_for(request):
    from types import SimpleNamespace

    return SimpleNamespace(context=request)


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


def test_register_email_sends_activation(settings, db, mailoutbox):
    settings.AUTH_EMAIL_REQUIRE_ACTIVATION = True
    request = make_request()
    result = auth.RegisterEmail.mutate(None, info_for(request), email="newbie@example.com", password="s3curePass!42")
    assert result["ok"] is True
    assert result["user"] is None  # not signed in until activated
    user = User.objects.get(email="newbie@example.com")
    assert user.is_active is False
    assert len(mailoutbox) == 1
    # The emailed key must decode to the username through the same salt the
    # existing /accounts/activate/ endpoint uses, so activation works end-to-end.
    key = mailoutbox[0].body.split("/accounts/activate/", 1)[1].split()[0]
    assert signing.loads(key, salt=auth.REGISTRATION_SALT) == user.get_username()


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
