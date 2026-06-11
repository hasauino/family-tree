"""GraphQL mutations for the signed-in user's own account: profile fields,
profile picture, and account deletion.
"""

import base64
import binascii

import graphene
from django.contrib.auth import get_user_model
from django.contrib.auth import logout as auth_logout
from django.core.files.base import ContentFile

from .auth import AuthReply
from .decorators import authenticated_only

User = get_user_model()

# Generous cap on the *decoded* image bytes the client may upload. The client
# resizes to 128x128 JPEG before sending, so a real upload is a few KB; this
# just guards against abuse.
MAX_IMAGE_BYTES = 2 * 1024 * 1024


class UpdateProfile(graphene.Mutation, AuthReply):
    """Updates the signed-in user's editable profile fields. Omitted
    arguments leave the corresponding field unchanged."""

    class Arguments:
        first_name = graphene.String(required=False)
        last_name = graphene.String(required=False)
        father_name = graphene.String(required=False)
        grandfather_name = graphene.String(required=False)
        birth_date = graphene.Date(required=False)
        birth_place = graphene.String(required=False)
        email = graphene.String(required=False)

    @authenticated_only
    def mutate(
        root,
        info,
        first_name=None,
        last_name=None,
        father_name=None,
        grandfather_name=None,
        birth_date=None,
        birth_place=None,
        email=None,
    ):
        user = info.context.user
        if email is not None:
            email = email.strip()
            if not email or "@" not in email:
                return AuthReply.fail("Enter a valid email address")
            if User.objects.exclude(pk=user.pk).filter(email__iexact=email).exists():
                return AuthReply.fail("An account with this email already exists")
            user.email = email
        if first_name is not None:
            user.first_name = first_name.strip()
        if last_name is not None:
            user.last_name = last_name.strip()
        if father_name is not None:
            user.father_name = father_name.strip()
        if grandfather_name is not None:
            user.grandfather_name = grandfather_name.strip()
        if birth_place is not None:
            user.birth_place = birth_place.strip()
        if birth_date is not None:
            user.birth_date = birth_date
        user.save()
        return AuthReply.success(user)


class UploadProfileImage(graphene.Mutation, AuthReply):
    """Replaces the signed-in user's profile picture with a base64-encoded
    JPEG (the client resizes/encodes the image before sending)."""

    class Arguments:
        image_base64 = graphene.String(required=True)

    @authenticated_only
    def mutate(root, info, image_base64):
        user = info.context.user
        try:
            data = base64.b64decode(image_base64, validate=True)
        except (binascii.Error, ValueError):
            return AuthReply.fail("Invalid image data")
        if not data:
            return AuthReply.fail("Invalid image data")
        if len(data) > MAX_IMAGE_BYTES:
            return AuthReply.fail("Image is too large")
        if user.profile_image:
            user.profile_image.delete(save=False)
        user.profile_image.save(f"user_{user.pk}.jpg", ContentFile(data), save=True)
        return AuthReply.success(user)


class RemoveProfileImage(graphene.Mutation, AuthReply):
    """Removes the signed-in user's profile picture, if any."""

    @authenticated_only
    def mutate(root, info):
        user = info.context.user
        if user.profile_image:
            user.profile_image.delete(save=False)
            user.profile_image = None
            user.save()
        return AuthReply.success(user)


class DeleteAccount(graphene.Mutation):
    """Permanently deletes the signed-in user's account and signs them out."""

    ok = graphene.Boolean()
    message = graphene.String()

    @authenticated_only
    def mutate(root, info):
        user = info.context.user
        if user.profile_image:
            user.profile_image.delete(save=False)
        auth_logout(info.context)
        user.delete()
        return DeleteAccount(ok=True, message="")
