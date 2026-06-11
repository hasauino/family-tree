"""Tests for the notification service, audit-on-publish, and the notification
GraphQL surface. Push is exercised indirectly: it's a no-op here because no
Firebase credentials are configured, so the service-layer logic runs without
network calls."""

from types import SimpleNamespace

from main import notifications as notify_service
from main.graphql import notifications as gql
from main.graphql.notifications import BatchPublish
from main.graphql.schema import AddPerson, EditPerson, MovePerson, PublishPerson
from main.models import Notification


def info_for(user):
    return SimpleNamespace(context=SimpleNamespace(user=user))


# ---------------------------------------------------------------------------
# Service-layer aggregation
# ---------------------------------------------------------------------------


def test_pending_addition_notifies_each_admin(make_person, normal_user, staff_user):
    other_admin = type(staff_user).objects.create_user(username="admin2", is_staff=True)
    person = make_person(name="Newcomer", access="private", editors=[normal_user])

    notify_service.notify_pending_addition(person, normal_user)

    assert Notification.objects.filter(recipient=staff_user, kind=Notification.PENDING_ADDITION).count() == 1
    assert Notification.objects.filter(recipient=other_admin, kind=Notification.PENDING_ADDITION).count() == 1


def test_pending_additions_aggregate_per_user(make_person, normal_user, staff_user):
    p1 = make_person(name="One", access="private", editors=[normal_user])
    p2 = make_person(name="Two", access="private", editors=[normal_user])

    notify_service.notify_pending_addition(p1, normal_user)
    notify_service.notify_pending_addition(p2, normal_user)

    notifs = Notification.objects.filter(recipient=staff_user, kind=Notification.PENDING_ADDITION)
    assert notifs.count() == 1  # aggregated, not spammed
    notif = notifs.first()
    assert notif.count == 2
    assert set(notif.data["person_ids"]) == {p1.pk, p2.pk}


def test_staff_addition_does_not_notify(make_person, staff_user):
    person = make_person(name="StaffAdd", access="public", editors=[staff_user])
    notify_service.notify_pending_addition(person, staff_user)
    assert Notification.objects.filter(kind=Notification.PENDING_ADDITION).count() == 0


def test_node_changed_aggregates_fields_per_node(make_person, normal_user, staff_user):
    person = make_person(name="Edited", access="private", editors=[normal_user])

    notify_service.notify_node_changed(person, staff_user, ["name"])
    notify_service.notify_node_changed(person, staff_user, ["history"])

    notifs = Notification.objects.filter(recipient=normal_user, kind=Notification.NODE_CHANGED)
    assert notifs.count() == 1
    assert set(notifs.first().data["fields"]) == {"name", "history"}


def test_node_changed_skips_the_actor(make_person, normal_user):
    person = make_person(name="Self", access="private", editors=[normal_user])
    notify_service.notify_node_changed(person, normal_user, ["name"])
    assert Notification.objects.filter(recipient=normal_user).count() == 0


def test_change_verified_notifies_original_editor(make_person, normal_user, staff_user):
    person = make_person(name="ToPublish", access="private", editors=[normal_user])
    notify_service.notify_change_verified(person, staff_user)
    assert Notification.objects.filter(recipient=normal_user, kind=Notification.CHANGE_VERIFIED).count() == 1


def test_broadcast_reaches_all_other_users(normal_user, staff_user, other_user):
    sent = notify_service.broadcast("Eid Mubarak", "Happy Eid!", staff_user)
    assert sent == 2  # normal + other, not the sender
    assert Notification.objects.filter(kind=Notification.BROADCAST, recipient=normal_user).exists()
    assert not Notification.objects.filter(kind=Notification.BROADCAST, recipient=staff_user).exists()


# ---------------------------------------------------------------------------
# Mutation hooks + audit
# ---------------------------------------------------------------------------


def test_add_person_by_normal_user_notifies_admins(make_person, normal_user, staff_user):
    root = make_person(name="Root")
    AddPerson.mutate(None, info_for(normal_user), id=root.pk, child_name="Kid")
    assert Notification.objects.filter(recipient=staff_user, kind=Notification.PENDING_ADDITION).exists()


def test_publish_person_records_audit_and_keeps_original_editors(make_person, normal_user, staff_user):
    person = make_person(name="Pending", access="private", editors=[normal_user])

    PublishPerson.mutate(None, info_for(staff_user), id=person.pk)

    person.refresh_from_db()
    assert person.access == "public"
    assert person.verified_by == staff_user
    assert person.verified_at is not None
    editors = set(person.editors.all())
    assert normal_user in editors  # original editor kept
    assert staff_user in editors  # verifier added
    assert Notification.objects.filter(recipient=normal_user, kind=Notification.CHANGE_VERIFIED).exists()


def test_edit_person_only_notifies_on_real_change(make_person, normal_user, staff_user):
    person = make_person(name="Name", designation="d", access="private", editors=[normal_user])
    # No-op edit (same values) → no notification.
    EditPerson.mutate(None, info_for(staff_user), id=person.pk, name="Name", designation="d")
    assert not Notification.objects.filter(recipient=normal_user, kind=Notification.NODE_CHANGED).exists()
    # Real change → notification.
    EditPerson.mutate(None, info_for(staff_user), id=person.pk, name="NewName")
    assert Notification.objects.filter(recipient=normal_user, kind=Notification.NODE_CHANGED).exists()


def test_move_person_notifies_editors(make_person, normal_user, staff_user):
    a = make_person(name="A")
    b = make_person(name="B")
    person = make_person(name="Movable", parent=a, access="private", editors=[normal_user])
    MovePerson.mutate(None, info_for(staff_user), id=person.pk, new_parent_id=b.pk)
    notif = Notification.objects.filter(recipient=normal_user, kind=Notification.NODE_CHANGED).first()
    assert notif is not None
    assert "parent" in notif.data["fields"]


# ---------------------------------------------------------------------------
# GraphQL queries / mutations
# ---------------------------------------------------------------------------


def test_resolve_notifications_returns_unread_count(make_person, normal_user, staff_user):
    person = make_person(name="X", access="private", editors=[normal_user])
    notify_service.notify_change_verified(person, staff_user)

    page = gql.NotificationQueries.resolve_notifications(None, info_for(normal_user))
    assert page.unread_count == 1
    assert len(page.notifications) == 1
    assert page.notifications[0].is_read is False


def test_mark_all_notifications_read(make_person, normal_user, staff_user):
    person = make_person(name="Y", access="private", editors=[normal_user])
    notify_service.notify_change_verified(person, staff_user)

    gql.MarkAllNotificationsRead.mutate(None, info_for(normal_user))

    assert Notification.objects.filter(recipient=normal_user, read_at__isnull=True).count() == 0


def test_mark_single_notification_read(make_person, normal_user, staff_user):
    person = make_person(name="Z", access="private", editors=[normal_user])
    notify_service.notify_change_verified(person, staff_user)
    notif = Notification.objects.get(recipient=normal_user)

    gql.MarkNotificationRead.mutate(None, info_for(normal_user), id=notif.pk)

    notif.refresh_from_db()
    assert notif.read_at is not None


def test_pending_additions_query_lists_private_persons(make_person, normal_user, staff_user):
    make_person(name="Private1", access="private", editors=[normal_user])
    make_person(name="PublicOne", access="public")

    result = gql.NotificationQueries.resolve_pending_additions(None, info_for(staff_user))

    names = {r.name for r in result}
    assert any("Private1" in n for n in names)
    assert all("PublicOne" not in n for n in names)


def test_batch_publish_verifies_selected(make_person, normal_user, staff_user):
    p1 = make_person(name="B1", access="private", editors=[normal_user])
    p2 = make_person(name="B2", access="private", editors=[normal_user])

    result = BatchPublish.mutate(None, info_for(staff_user), ids=[p1.pk, p2.pk])

    assert result["published"] == 2
    p1.refresh_from_db()
    p2.refresh_from_db()
    assert p1.access == "public" and p2.access == "public"
    assert p1.verified_by == staff_user


def test_register_and_unregister_device_token(normal_user):
    gql.RegisterDeviceToken.mutate(None, info_for(normal_user), token="tok123", platform="android")
    assert normal_user.device_tokens.filter(token="tok123").exists()
    gql.UnregisterDeviceToken.mutate(None, info_for(normal_user), token="tok123")
    assert not normal_user.device_tokens.filter(token="tok123").exists()


def test_broadcast_notification_requires_message(staff_user):
    result = gql.BroadcastNotification.mutate(None, info_for(staff_user), title="", body="")
    assert result["ok"] is False
