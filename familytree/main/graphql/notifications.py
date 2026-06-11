"""GraphQL surface for notifications and admin verification.

Covers four areas:

* **In-app notifications** for the bell: list, unread count, mark one/all read.
* **Verification** (admin): a rich list of pending additions for filtering and
  batch approval client-side, plus a ``batchPublish`` mutation.
* **Broadcast** (admin): send a custom message to all users.
* **Push**: register/unregister this device's FCM token.

The list resolvers return plain object payloads (not Django models) so the
aggregated ``body``/``count`` are surfaced exactly as stored.
"""

import graphene
from django.utils import timezone

from main import notifications as notify_service
from main.models import DeviceToken, Notification, Person

from .decorators import authenticated_only, staff_only


class MutationReply:
    ok = graphene.Boolean()
    message = graphene.String()

    @staticmethod
    def success(message=""):
        return {"ok": True, "message": message}

    @staticmethod
    def fail(message=""):
        return {"ok": False, "message": message}


class NotificationType(graphene.ObjectType):
    """One bell entry. Aggregated entries carry ``count`` > 1 and a body that
    already summarises the folded-in events."""

    id = graphene.Int()
    kind = graphene.String(description="pending_addition | change_verified | node_changed | broadcast")
    title = graphene.String()
    body = graphene.String()
    count = graphene.Int(description="How many events are aggregated into this entry")
    is_read = graphene.Boolean()
    created_at = graphene.DateTime()
    updated_at = graphene.DateTime()
    actor_name = graphene.String(description="Display name of who triggered it, if any")
    person_id = graphene.Int(description="Primary related person to navigate to, if any")
    person_ids = graphene.List(graphene.Int, description="All related person ids (for aggregated entries)")

    @staticmethod
    def from_model(n: Notification):
        actor_name = None
        if n.actor:
            actor_name = n.actor.get_full_name() or n.actor.username
        return NotificationType(
            id=n.id,
            kind=n.kind,
            title=n.title,
            body=n.body,
            count=n.count,
            is_read=n.read_at is not None,
            created_at=n.created_at,
            updated_at=n.updated_at,
            actor_name=actor_name,
            person_id=n.person_id,
            person_ids=n.data.get("person_ids", []),
        )


class NotificationPage(graphene.ObjectType):
    notifications = graphene.List(NotificationType)
    unread_count = graphene.Int()
    total = graphene.Int()


class PendingEditor(graphene.ObjectType):
    """The contributor attached to a pending addition (for the verification list)."""

    id = graphene.Int()
    name = graphene.String()
    email = graphene.String()
    user_type = graphene.String(description="'Staff' or 'normal'")


class PendingAddition(graphene.ObjectType):
    """A private (unpublished) person awaiting admin verification, with the
    metadata the admin filters/sorts/selects on."""

    id = graphene.Int()
    name = graphene.String(description="Full name including ancestors")
    creation_time = graphene.DateTime()
    last_modified = graphene.DateTime()
    editors = graphene.List(PendingEditor)


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------


class NotificationQueries(graphene.ObjectType):
    """Mixed into the root Query (see schema.py)."""

    notifications = graphene.Field(
        NotificationPage,
        description="The signed-in user's notifications, newest first.",
        limit=graphene.Int(required=False, default_value=50),
        offset=graphene.Int(required=False, default_value=0),
    )
    unread_notification_count = graphene.Int(description="Number of unread notifications for the signed-in user.")
    pending_additions = graphene.List(
        PendingAddition,
        description="All unpublished (private) persons awaiting verification. Staff only.",
    )

    @authenticated_only
    def resolve_notifications(parent, info, limit=50, offset=0):
        user = info.context.user
        qs = Notification.objects.filter(recipient=user)
        total = qs.count()
        unread = qs.filter(read_at__isnull=True).count()
        rows = list(qs.select_related("actor", "person")[offset : offset + limit])
        return NotificationPage(
            notifications=[NotificationType.from_model(n) for n in rows],
            unread_count=unread,
            total=total,
        )

    @authenticated_only
    def resolve_unread_notification_count(parent, info):
        return Notification.objects.filter(recipient=info.context.user, read_at__isnull=True).count()

    @staff_only
    def resolve_pending_additions(parent, info):
        result = []
        qs = Person.objects.filter(access="private").prefetch_related("editors").order_by("-creation_time")
        for person in qs:
            editors = [
                PendingEditor(
                    id=e.id,
                    name=(e.get_full_name() or e.username),
                    email=e.email,
                    user_type=e.user_type,
                )
                for e in person.editors.all()
            ]
            result.append(
                PendingAddition(
                    id=person.id,
                    name=str(person),
                    creation_time=person.creation_time,
                    last_modified=person.last_modified,
                    editors=editors,
                )
            )
        return result


# ---------------------------------------------------------------------------
# Mutations
# ---------------------------------------------------------------------------


class MarkNotificationRead(graphene.Mutation, MutationReply):
    class Arguments:
        id = graphene.Int(required=True)

    @authenticated_only
    def mutate(root, info, id):
        notif = Notification.objects.filter(pk=id, recipient=info.context.user).first()
        if notif is None:
            return MutationReply.fail("Notification not found")
        notif.mark_read()
        return MutationReply.success()


class MarkAllNotificationsRead(graphene.Mutation, MutationReply):
    @authenticated_only
    def mutate(root, info):
        Notification.objects.filter(recipient=info.context.user, read_at__isnull=True).update(read_at=timezone.now())
        return MutationReply.success()


class BatchPublish(graphene.Mutation, MutationReply):
    """Publish (verify) many pending persons at once. Records the verifying
    admin + timestamp, keeps the original editors, adds the admin as an editor,
    and notifies the original contributors. Mirrors PublishPerson per node."""

    class Arguments:
        ids = graphene.List(graphene.NonNull(graphene.Int), required=True)

    published = graphene.Int()

    @staff_only
    def mutate(root, info, ids):
        user = info.context.user
        now = timezone.now()
        published = 0
        for pid in ids:
            person = Person.objects.filter(pk=pid).first()
            if person is None or person.access == "public":
                continue
            person.access = "public"
            person.verified_by = user
            person.verified_at = now
            person.editors.add(user)
            person.save()
            notify_service.notify_change_verified(person, user)
            published += 1
        return {**MutationReply.success(), "published": published}


class BroadcastNotification(graphene.Mutation, MutationReply):
    """Send a custom notification to all users (e.g. an Eid greeting). Staff only."""

    class Arguments:
        title = graphene.String(required=True)
        body = graphene.String(required=True)

    sent = graphene.Int()

    @staff_only
    def mutate(root, info, title, body):
        title = (title or "").strip()
        body = (body or "").strip()
        if not title and not body:
            return {**MutationReply.fail("Message cannot be empty"), "sent": 0}
        sent = notify_service.broadcast(title, body, info.context.user)
        return {**MutationReply.success(), "sent": sent}


class RegisterDeviceToken(graphene.Mutation, MutationReply):
    """Register this device's FCM token for push delivery (idempotent)."""

    class Arguments:
        token = graphene.String(required=True)
        platform = graphene.String(required=False, default_value="")

    @authenticated_only
    def mutate(root, info, token, platform=""):
        token = (token or "").strip()
        if not token:
            return MutationReply.fail("Empty token")
        DeviceToken.objects.update_or_create(
            token=token,
            defaults={"user": info.context.user, "platform": platform},
        )
        return MutationReply.success()


class UnregisterDeviceToken(graphene.Mutation, MutationReply):
    """Drop a device token (e.g. on sign-out) so it stops receiving push."""

    class Arguments:
        token = graphene.String(required=True)

    @authenticated_only
    def mutate(root, info, token):
        DeviceToken.objects.filter(token=token, user=info.context.user).delete()
        return MutationReply.success()
