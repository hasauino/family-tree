"""Creation and aggregation of :class:`~main.models.Notification` rows.

The public entry points are the ``notify_*`` helpers, each called from a GraphQL
mutation when something happens. They funnel through :func:`_aggregate`, which
either opens a fresh notification or folds the event into the recipient's
existing *unread* one for the same bucket — so a burst of edits to one node, or
many additions by one user, collapses into a single bell entry. Each helper then
triggers a (throttled, best-effort) push via :mod:`main.push`.
"""

from datetime import timedelta

from django.contrib.auth import get_user_model
from django.utils import timezone
from django.utils.translation import gettext as _

from main import push
from main.models import Notification

User = get_user_model()

# Don't list more than this many distinct items inline in an aggregated body;
# beyond it we say "… and N more" to keep the message short.
MAX_INLINE_ITEMS = 5
# Minimum gap between pushes for the *same* (still-unread) aggregated
# notification, so rapid repeat events don't buzz the device repeatedly.
PUSH_THROTTLE = timedelta(seconds=60)

# Human-readable labels for the editable fields referenced by node_changed.
FIELD_LABELS = {
    "name": _("name"),
    "designation": _("designation"),
    "history": _("history"),
    "parent": _("parent"),
}


def _staff_users():
    return User.objects.filter(is_staff=True, is_active=True)


def _unread_recipients(person, exclude=None):
    """Non-staff editors of ``person`` (the people who "own" the entry), minus
    ``exclude`` — used to notify the original contributors of a node."""
    recipients = person.editors.filter(is_staff=False, is_active=True)
    if exclude is not None:
        recipients = recipients.exclude(pk=exclude.pk)
    return recipients


def _aggregate(recipient, kind, group_key, *, actor, person, title, body, data, push_title, push_body):
    """Open or update-in-place the unread notification for this bucket, then push."""
    notif = Notification.objects.filter(
        recipient=recipient, kind=kind, group_key=group_key, read_at__isnull=True
    ).first()
    if notif is None:
        notif = Notification(recipient=recipient, kind=kind, group_key=group_key, count=0, data={})
    notif.actor = actor
    if person is not None:
        notif.person = person
    notif.title = title
    notif.body = body
    notif.data = data
    notif.count = data.get("count", notif.count + 1)
    notif.save()

    # Throttled, best-effort push.
    now = timezone.now()
    if notif.last_pushed_at is None or now - notif.last_pushed_at >= PUSH_THROTTLE:
        delivered = push.send_to_user(
            recipient,
            title=push_title,
            body=push_body,
            data={"notification_id": notif.id, "kind": kind, "person_id": person.id if person else ""},
        )
        if delivered:
            notif.last_pushed_at = now
            notif.save(update_fields=["last_pushed_at"])
    return notif


def _append_unique(items, value, limit=None):
    """Append ``value`` to ``items`` if absent (order-preserving)."""
    if value not in items:
        items.append(value)
    return items


# ---------------------------------------------------------------------------
# Public helpers — one per event type
# ---------------------------------------------------------------------------


def notify_pending_addition(person, actor):
    """A regular user added ``person`` (still private). Tell every admin, with
    one aggregated entry per contributing user."""
    if actor.is_staff:
        return  # staff additions are auto-published; nothing to verify
    group_key = f"pending:{actor.pk}"
    actor_name = actor.get_full_name() or actor.username
    for admin in _staff_users():
        existing = Notification.objects.filter(
            recipient=admin, kind=Notification.PENDING_ADDITION, group_key=group_key, read_at__isnull=True
        ).first()
        names = list(existing.data.get("names", [])) if existing else []
        ids = list(existing.data.get("person_ids", [])) if existing else []
        if person.pk not in ids:
            ids.append(person.pk)
            _append_unique(names, str(person))
        data = {"names": names, "person_ids": ids, "count": len(ids), "actor_id": actor.pk}
        body = _format_addition_body(actor_name, names, len(ids))
        _aggregate(
            admin,
            Notification.PENDING_ADDITION,
            group_key,
            actor=actor,
            person=person,
            title=_("New additions to verify"),
            body=body,
            data=data,
            push_title=_("New additions to verify"),
            push_body=body,
        )


def notify_node_changed(person, actor, changed_fields):
    """Someone edited ``person``. Tell its original (non-staff) contributors,
    aggregating repeat edits to the same node into one entry."""
    changed_fields = [f for f in changed_fields if f]
    if not changed_fields:
        return
    group_key = f"changed:{person.pk}"
    for recipient in _unread_recipients(person, exclude=actor):
        existing = Notification.objects.filter(
            recipient=recipient, kind=Notification.NODE_CHANGED, group_key=group_key, read_at__isnull=True
        ).first()
        fields = list(existing.data.get("fields", [])) if existing else []
        change_count = (existing.data.get("change_count", 0) if existing else 0) + len(changed_fields)
        for f in changed_fields:
            _append_unique(fields, f)
        data = {"fields": fields, "change_count": change_count, "count": change_count, "person_id": person.pk}
        body = _format_changed_body(str(person), fields)
        _aggregate(
            recipient,
            Notification.NODE_CHANGED,
            group_key,
            actor=actor,
            person=person,
            title=_("Your entry was updated"),
            body=body,
            data=data,
            push_title=_("Your entry was updated"),
            push_body=body,
        )


def notify_change_verified(person, verifier):
    """``person`` was published/verified. Tell its original (non-staff)
    contributors, aggregating all of a user's verified entries into one."""
    group_key = "verified"
    for recipient in _unread_recipients(person, exclude=verifier):
        existing = Notification.objects.filter(
            recipient=recipient, kind=Notification.CHANGE_VERIFIED, group_key=group_key, read_at__isnull=True
        ).first()
        names = list(existing.data.get("names", [])) if existing else []
        ids = list(existing.data.get("person_ids", [])) if existing else []
        if person.pk not in ids:
            ids.append(person.pk)
            _append_unique(names, str(person))
        data = {"names": names, "person_ids": ids, "count": len(ids)}
        body = _format_verified_body(names, len(ids))
        _aggregate(
            recipient,
            Notification.CHANGE_VERIFIED,
            group_key,
            actor=verifier,
            person=person,
            title=_("Your additions were published"),
            body=body,
            data=data,
            push_title=_("Your additions were published"),
            push_body=body,
        )


def broadcast(title, body, sender, recipients=None):
    """Admin-authored custom message to many users (e.g. an Eid greeting).

    Each broadcast is its own non-aggregating notification (unique group key),
    so successive broadcasts never overwrite one another. Returns the count
    created."""
    if recipients is None:
        recipients = User.objects.filter(is_active=True).exclude(pk=sender.pk)
    group_key = f"broadcast:{timezone.now().timestamp()}"
    created = 0
    for recipient in recipients:
        notif = Notification.objects.create(
            recipient=recipient,
            kind=Notification.BROADCAST,
            group_key=group_key,
            actor=sender,
            title=title,
            body=body,
            count=1,
            data={},
        )
        push.send_to_user(
            recipient, title=title, body=body, data={"notification_id": notif.id, "kind": Notification.BROADCAST}
        )
        created += 1
    return created


# ---------------------------------------------------------------------------
# Body formatting
# ---------------------------------------------------------------------------


def _join_inline(items):
    shown = items[:MAX_INLINE_ITEMS]
    text = "، ".join(shown) if _is_rtl() else ", ".join(shown)
    extra = len(items) - len(shown)
    if extra > 0:
        text += " " + _("and %(n)d more") % {"n": extra}
    return text


def _is_rtl():
    # Cheap RTL check for joining; the active locale is set per-request.
    from django.utils.translation import get_language

    return (get_language() or "").startswith("ar")


def _format_addition_body(actor_name, names, count):
    if count == 1:
        return _("%(user)s added %(name)s") % {"user": actor_name, "name": names[0]}
    return _("%(user)s added %(count)d people: %(list)s") % {
        "user": actor_name,
        "count": count,
        "list": _join_inline(names),
    }


def _format_changed_body(person_name, fields):
    labels = [str(FIELD_LABELS.get(f, f)) for f in fields]
    return _("Your entry “%(name)s” was updated (%(fields)s)") % {
        "name": person_name,
        "fields": _join_inline(labels),
    }


def _format_verified_body(names, count):
    if count == 1:
        return _("“%(name)s” was published") % {"name": names[0]}
    return _("%(count)d of your additions were published: %(list)s") % {
        "count": count,
        "list": _join_inline(names),
    }
