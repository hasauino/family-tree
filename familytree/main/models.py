import secrets
from collections import deque
from datetime import timedelta

from django.conf import settings
from django.contrib.auth.hashers import check_password, make_password
from django.contrib.auth.models import AbstractUser
from django.core.validators import EmailValidator
from django.db import models
from django.utils import timezone
from django.utils.translation import gettext_lazy as _

User = settings.AUTH_USER_MODEL

N_COLORS = 11  # number of colors in the tree color palette/theme (check main/static/tree_color_palettes.js)


class Person(models.Model):
    name = models.CharField(max_length=200, verbose_name=_("Name"))
    parent = models.ForeignKey(
        "self", on_delete=models.CASCADE, null=True, blank=True, related_name="children", verbose_name=_("Parent")
    )
    reference = models.TextField(max_length=1000, blank=True, verbose_name=_("Reference of authentication (optional)"))
    designation = models.TextField(max_length=500, blank=True, verbose_name=_("Designation (optional)"))
    history = models.TextField(max_length=2000, blank=True, verbose_name=_("Historical Background (optional)"))
    editors = models.ManyToManyField(User, verbose_name=_("Editor"))
    access_choices = [("public", "public"), ("private", "private")]
    access = models.CharField(max_length=200, choices=access_choices, default="public")
    creation_time = models.DateTimeField(auto_now_add=True, verbose_name=_("Date of creation"))
    last_modified = models.DateTimeField(auto_now=True, verbose_name=_("Date of last modification"))
    # Audit of who approved/published this person and when (set on publish). The
    # publishing admin is also added to ``editors`` (without removing the
    # original editors), so this records *which* admin did it and *when*.
    verified_by = models.ForeignKey(
        User,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="+",
        verbose_name=_("Verified by"),
    )
    verified_at = models.DateTimeField(null=True, blank=True, verbose_name=_("Date of verification"))

    def is_visible_to(self, user: User):
        """
        Checks whether the given user has view permission
        """
        if self.access == "public":
            return True
        if user.is_staff:
            return True
        return user in self.editors.all()

    def is_editable_by(self, user: User):
        """
        Checks whether the given user has edit permission
        """
        if user.is_staff:
            return True
        if self.is_public():
            return False
        editors = self.editors.all()
        if user in editors and len(editors) == 1:
            return True
        return False

    def expand(self, depth=5):
        buffer = deque([self])
        # all_persons = []
        levels = []
        while len(buffer) > 0 and depth >= 0:
            depth -= 1
            new_buffer = deque([])
            level = []
            while len(buffer) > 0:
                person = buffer.pop()
                # all_persons.append(person)
                level.append(person)
                new_buffer.extend(list(person.children.all()))
            levels.append(level)
            buffer = new_buffer
        return levels

    def get_grandfather(self):
        if self.parent is None:
            return None
        if self.parent.parent is None:
            return None
        return self.parent.parent

    def _get_father(self, parent, depth):
        try:
            if depth > 1:
                return parent.name + " " + self._get_father(parent.parent, depth - 1)
            else:
                return ""
        except AttributeError:
            return ""

    def __str__(self):
        return self.name + " " + self._get_father(self.parent, 6)

    def is_public(self):
        return self.access == "public"

    def is_bookmarked(self):
        return hasattr(self, "bookmark")

    def as_node(self, user: User = None, forced_group=None):
        """
        Returns the vis.js node representation
        """
        opacity = 1.0
        if user is not None and user.is_staff:
            opacity = 1.0 if self.is_public() else 0.3
        if forced_group is None:
            group_code = f"g{(self.parent.pk if self.parent else 0) % N_COLORS}"
        else:
            group_code = f"g{forced_group}"
        title = f"{self.designation}\n{self.history}"
        visible_children = sum(1 for c in self.children.all() if c.is_visible_to(user))
        has_parent = self.parent is not None and self.parent.is_visible_to(user)
        data = {
            "id": self.pk,
            "label": self.name,
            "group": group_code,
            "opacity": opacity,
            "child_count": visible_children,
            "has_parent": has_parent,
        }
        if len(title) > 1:
            data["title"] = title
            data["font"] = {
                "strokeWidth": 5,
            }
        return data

    def find_closest_parent(self, persons):
        """
        Returns closest parent among given persons list, and how far is it
        """
        parent = self.parent
        length = 1
        while parent is not None:
            if parent in persons:
                return parent, length
            length += 1
            parent = parent.parent
        return None, -1

    def remove_editor(self, user):
        editors = list(self.editors.all())
        if len(editors) == 1 and editors[0].is_staff:
            return
        self.editors.remove(user)
        self.save()


class User(AbstractUser):
    email = models.EmailField(
        null=True, blank=True, unique=True, validators=[EmailValidator(message=_("Enter a valid email address"))]
    )
    birth_date = models.DateField(null=True, blank=False, verbose_name=_("Date of birth"))

    first_name = models.CharField(max_length=150, null=True, blank=False, verbose_name=_("First name"))
    father_name = models.CharField(max_length=150, null=True, blank=False, verbose_name=_("Father's name"))
    grandfather_name = models.CharField(max_length=150, null=True, blank=False, verbose_name=_("Grandfather's name"))
    last_name = models.CharField(max_length=150, null=True, blank=False, verbose_name=_("Last name"))

    birth_place = models.CharField(max_length=150, null=True, blank=False, verbose_name=_("Place of birth"))

    profile_image = models.ImageField(
        upload_to="profile_images/", null=True, blank=True, verbose_name=_("Profile picture")
    )

    @property
    def user_type(self):
        if self.is_superuser:
            return "Staff"
        if self.is_staff:
            return "Staff"
        if self.is_authenticated:
            return "normal"
        return "Anonymous"


class EmailVerification(models.Model):
    """A short-lived numeric code emailed to confirm an action by its owner.

    Backs both sign-up email verification and password reset, told apart by
    ``purpose``. One row per (user, purpose), replaced on each (re)send; the code
    is stored hashed and verification is expiry- and attempt-limited so it can't
    be brute-forced.
    """

    ACTIVATION = "activation"
    PASSWORD_RESET = "password_reset"
    PURPOSES = [(ACTIVATION, "Email verification"), (PASSWORD_RESET, "Password reset")]

    CODE_LENGTH = 6
    TTL = timedelta(seconds=getattr(settings, "EMAIL_CODE_TTL_SECONDS", 600))
    RESEND_COOLDOWN = timedelta(seconds=getattr(settings, "EMAIL_CODE_RESEND_COOLDOWN_SECONDS", 60))
    MAX_ATTEMPTS = getattr(settings, "EMAIL_CODE_MAX_ATTEMPTS", 5)

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="email_verifications")
    purpose = models.CharField(max_length=32, choices=PURPOSES, default=ACTIVATION)
    code_hash = models.CharField(max_length=128)
    created_at = models.DateTimeField(default=timezone.now)
    attempts = models.PositiveSmallIntegerField(default=0)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["user", "purpose"], name="unique_user_purpose_code"),
        ]

    @classmethod
    def issue_for(cls, user, purpose):
        """Generate, store (hashed), and return a fresh plaintext code."""
        code = f"{secrets.randbelow(10**cls.CODE_LENGTH):0{cls.CODE_LENGTH}d}"
        cls.objects.update_or_create(
            user=user,
            purpose=purpose,
            defaults={"code_hash": make_password(code), "created_at": timezone.now(), "attempts": 0},
        )
        return code

    @classmethod
    def active_for(cls, user, purpose):
        """The pending code row for (user, purpose), or None."""
        return cls.objects.filter(user=user, purpose=purpose).first()

    @property
    def is_expired(self):
        return timezone.now() >= self.created_at + self.TTL

    @property
    def seconds_until_resend(self):
        remaining = (self.created_at + self.RESEND_COOLDOWN) - timezone.now()
        return max(0, int(remaining.total_seconds()))

    def matches(self, code):
        return check_password(code or "", self.code_hash)


class Notification(models.Model):
    """An in-app (and optionally push) notification for a single recipient.

    Notifications **aggregate** so the bell never spams: instead of one row per
    event, an *unread* notification with the same ``(recipient, kind,
    group_key)`` is updated in place — its ``count`` grows and ``data``
    accumulates detail — so the recipient sees one entry that reads e.g. "Ali
    added 5 people" or "Your entry for <name> had 3 changes". Marking it read
    "closes" it; the next event then opens a fresh notification.

    Kinds:
      * ``pending_addition`` – admin-facing: a regular user added node(s) that
        await verification. Grouped per actor (one entry per contributing user).
      * ``change_verified``  – user-facing: additions of theirs were published.
      * ``node_changed``     – user-facing: a node they added was edited by
        someone else. Grouped per node.
      * ``broadcast``        – admin-authored custom message sent to users.
    """

    PENDING_ADDITION = "pending_addition"
    CHANGE_VERIFIED = "change_verified"
    NODE_CHANGED = "node_changed"
    BROADCAST = "broadcast"
    KINDS = [
        (PENDING_ADDITION, _("Pending addition")),
        (CHANGE_VERIFIED, _("Change verified")),
        (NODE_CHANGED, _("Node changed")),
        (BROADCAST, _("Broadcast")),
    ]

    recipient = models.ForeignKey(User, on_delete=models.CASCADE, related_name="notifications")
    kind = models.CharField(max_length=32, choices=KINDS)
    actor = models.ForeignKey(
        User, null=True, blank=True, on_delete=models.SET_NULL, related_name="+", verbose_name=_("Triggered by")
    )
    person = models.ForeignKey(Person, null=True, blank=True, on_delete=models.SET_NULL, related_name="+")
    title = models.CharField(max_length=255, blank=True)
    body = models.TextField(blank=True)
    # Aggregation bucket. While an unread notification shares this key with a new
    # event, that event folds into it instead of creating another row.
    group_key = models.CharField(max_length=255, db_index=True)
    count = models.PositiveIntegerField(default=1, help_text=_("Number of aggregated events"))
    # Free-form detail used to render the aggregated body, e.g.
    # {"person_ids": [..], "names": [..], "fields": ["name", "history"]}.
    data = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    read_at = models.DateTimeField(null=True, blank=True)
    # When a push was last delivered for this (aggregated) notification, used to
    # throttle repeat pushes while it keeps accumulating events.
    last_pushed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-updated_at"]
        indexes = [
            models.Index(fields=["recipient", "read_at"]),
            models.Index(fields=["recipient", "kind", "group_key"]),
        ]

    @property
    def is_read(self):
        return self.read_at is not None

    def mark_read(self):
        if self.read_at is None:
            self.read_at = timezone.now()
            self.save(update_fields=["read_at"])


class DeviceToken(models.Model):
    """An FCM registration token for one of a user's devices, used to deliver
    push notifications. Tokens are globally unique; re-registering an existing
    token just re-points it at the current user (e.g. after a device is handed
    over or a different account signs in)."""

    ANDROID = "android"
    IOS = "ios"
    WEB = "web"
    PLATFORMS = [(ANDROID, "Android"), (IOS, "iOS"), (WEB, "Web")]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="device_tokens")
    token = models.CharField(max_length=255, unique=True)
    platform = models.CharField(max_length=16, choices=PLATFORMS, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    last_seen = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.user} ({self.platform})"
