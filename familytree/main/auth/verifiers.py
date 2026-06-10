"""Verify Google / Apple / Facebook tokens and return a normalized profile.

Each provider hands the mobile app a token natively; we re-verify it on the
server (never trust the client) before trusting the identity inside it:

* Google & Apple issue OpenID-Connect **identity tokens** — signed JWTs. We
  fetch the provider's published JWKS, check the RS256 signature, and assert the
  issuer, audience (must be one of our configured client ids) and expiry.
* Facebook issues an **access token**. We call the Graph API to read the profile
  and `/debug_token` to confirm the token really belongs to our app.

No third-party SDK is needed: `PyJWT[crypto]` does the JWT work and the rest is
stdlib `urllib`.
"""

import json
import urllib.parse
import urllib.request
from dataclasses import dataclass

import jwt
from django.conf import settings
from jwt import PyJWKClient

GOOGLE_ISSUERS = ("https://accounts.google.com", "accounts.google.com")
GOOGLE_JWKS_URL = "https://www.googleapis.com/oauth2/v3/certs"

APPLE_ISSUER = "https://appleid.apple.com"
APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"

FACEBOOK_GRAPH = "https://graph.facebook.com"

_HTTP_TIMEOUT = 10


class SocialAuthError(Exception):
    """Raised when a provider token is missing, malformed, or fails verification."""


@dataclass
class SocialProfile:
    """The bits of a verified provider identity we provision a user from."""

    provider: str
    sub: str  # provider-stable unique id ("subject")
    email: str | None = None
    first_name: str = ""
    last_name: str = ""


# JWKS clients cache fetched signing keys internally (with their own TTL), so we
# keep one per provider rather than re-downloading the key set on every login.
_jwk_clients: dict[str, PyJWKClient] = {}


def _jwk_client(url: str) -> PyJWKClient:
    client = _jwk_clients.get(url)
    if client is None:
        client = PyJWKClient(url, lifespan=3600)
        _jwk_clients[url] = client
    return client


def _verify_oidc_token(token: str, *, jwks_url: str, issuers, audiences, provider: str) -> dict:
    """Verify an OIDC identity token (Google/Apple) and return its claims."""
    if not token:
        raise SocialAuthError(f"Missing {provider} token")
    if not audiences:
        raise SocialAuthError(f"{provider} sign-in is not configured")
    try:
        signing_key = _jwk_client(jwks_url).get_signing_key_from_jwt(token)
        return jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            audience=list(audiences),
            issuer=list(issuers),
            options={"require": ["exp", "iss", "aud", "sub"]},
        )
    except SocialAuthError:
        raise
    except Exception as exc:  # jwt.* errors, network errors, key lookup failures
        raise SocialAuthError(f"Could not verify {provider} token: {exc}") from exc


def verify_google(token: str) -> SocialProfile:
    claims = _verify_oidc_token(
        token,
        jwks_url=GOOGLE_JWKS_URL,
        issuers=GOOGLE_ISSUERS,
        audiences=settings.GOOGLE_CLIENT_IDS,
        provider="google",
    )
    return SocialProfile(
        provider="google",
        sub=claims["sub"],
        email=claims.get("email"),
        first_name=claims.get("given_name", ""),
        last_name=claims.get("family_name", ""),
    )


def verify_apple(token: str) -> SocialProfile:
    claims = _verify_oidc_token(
        token,
        jwks_url=APPLE_JWKS_URL,
        issuers=(APPLE_ISSUER,),
        audiences=settings.APPLE_CLIENT_IDS,
        provider="apple",
    )
    # Apple only includes the name on the very first authorization and never in
    # the identity token, so names usually arrive empty here; the client may
    # pass them separately. Email may be a private relay address.
    return SocialProfile(provider="apple", sub=claims["sub"], email=claims.get("email"))


def _http_get_json(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=_HTTP_TIMEOUT) as response:  # noqa: S310 (trusted provider URLs)
        return json.loads(response.read().decode())


def verify_facebook(token: str) -> SocialProfile:
    if not token:
        raise SocialAuthError("Missing facebook token")
    app_id = settings.FACEBOOK_APP_ID
    app_secret = settings.FACEBOOK_APP_SECRET
    if not app_id or not app_secret:
        raise SocialAuthError("facebook sign-in is not configured")
    try:
        # Confirm the token was issued for *our* app and is still valid.
        debug = _http_get_json(
            f"{FACEBOOK_GRAPH}/debug_token?"
            + urllib.parse.urlencode({"input_token": token, "access_token": f"{app_id}|{app_secret}"})
        )
        data = debug.get("data", {})
        if not data.get("is_valid") or str(data.get("app_id")) != str(app_id):
            raise SocialAuthError("facebook token is not valid for this app")

        profile = _http_get_json(
            f"{FACEBOOK_GRAPH}/me?"
            + urllib.parse.urlencode({"fields": "id,email,first_name,last_name", "access_token": token})
        )
    except SocialAuthError:
        raise
    except Exception as exc:
        raise SocialAuthError(f"Could not verify facebook token: {exc}") from exc

    return SocialProfile(
        provider="facebook",
        sub=profile["id"],
        email=profile.get("email"),
        first_name=profile.get("first_name", ""),
        last_name=profile.get("last_name", ""),
    )


_VERIFIERS = {
    "google": verify_google,
    "apple": verify_apple,
    "facebook": verify_facebook,
}


def verify_social_token(provider: str, token: str) -> SocialProfile:
    """Verify ``token`` against ``provider`` and return the normalized profile."""
    verifier = _VERIFIERS.get((provider or "").lower())
    if verifier is None:
        raise SocialAuthError(f"Unknown sign-in provider: {provider!r}")
    return verifier(token)
