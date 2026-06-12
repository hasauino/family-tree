"""Social sign-in support: provider token verification + user provisioning.

The mobile client obtains an identity/access token natively from Google, Apple
or Facebook and sends it to the GraphQL `socialLogin` mutation; the functions
here verify that token with the provider and turn the resulting profile into a
local Django user, so the rest of the app keeps using ordinary session auth.
"""

from .users import get_or_create_social_user
from .verifiers import SocialAuthError, SocialProfile, verify_social_token

__all__ = [
    "SocialAuthError",
    "SocialProfile",
    "get_or_create_social_user",
    "verify_social_token",
]
