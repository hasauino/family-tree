import json
import logging
import pathlib

import pytest
from django.urls import reverse

from main.models import User


# ---------------------------------------------------------------------------
# person_tree
# ---------------------------------------------------------------------------


def test_person_tree_renders_for_existing_person(client, make_person):
    person = make_person(name="Root")
    response = client.get(reverse("main:person_tree", args=(person.pk,)))
    assert response.status_code == 200
    assert response.context["main_id"] == person.pk
    data = json.loads(response.context["data"])
    assert any(node["id"] == person.pk for node in data)


def test_person_tree_404_for_missing_person(client, db):
    response = client.get(reverse("main:person_tree", args=(999999,)))
    assert response.status_code == 404


def test_person_tree_includes_grandfather_and_parent(client, make_person):
    grandparent = make_person(name="Grandparent")
    parent = make_person(name="Parent", parent=grandparent)
    person = make_person(name="Person", parent=parent)
    response = client.get(reverse("main:person_tree", args=(person.pk,)))
    data = json.loads(response.context["data"])
    ids = {node["id"] for node in data}
    assert {grandparent.pk, parent.pk, person.pk}.issubset(ids)


def test_person_tree_hides_private_persons_from_anonymous_users(client, make_person):
    parent = make_person(name="Parent", access="private")
    person = make_person(name="Person", parent=parent, access="public")
    response = client.get(reverse("main:person_tree", args=(person.pk,)))
    data = json.loads(response.context["data"])
    ids = {node["id"] for node in data}
    assert parent.pk not in ids
    assert person.pk in ids


# ---------------------------------------------------------------------------
# navigation
# ---------------------------------------------------------------------------


def test_navigation_view_renders(client, db):
    response = client.get(reverse("main:navigation"))
    assert response.status_code == 200


# ---------------------------------------------------------------------------
# tree_from_to
# ---------------------------------------------------------------------------


def test_tree_from_to_errors_when_from_person_missing(client, make_person):
    to_person = make_person(name="To")
    response = client.get(reverse("main:tree_from_to", args=(999999, to_person.pk)))
    assert response.status_code == 200
    assert "error" in response.context


def test_tree_from_to_errors_when_to_person_missing(client, make_person):
    from_person = make_person(name="From")
    response = client.get(reverse("main:tree_from_to", args=(from_person.pk, 999999)))
    assert response.status_code == 200
    assert "error" in response.context


def test_tree_from_to_errors_when_from_person_not_visible(client, make_person):
    from_person = make_person(name="From", access="private")
    child = make_person(name="Child", parent=from_person)
    response = client.get(reverse("main:tree_from_to", args=(from_person.pk, child.pk)))
    assert "error" in response.context


def test_tree_from_to_errors_when_intermediate_ancestor_not_visible(client, make_person):
    from_person = make_person(name="From", access="public")
    middle = make_person(name="Middle", parent=from_person, access="private")
    to_person = make_person(name="To", parent=middle, access="public")

    response = client.get(reverse("main:tree_from_to", args=(from_person.pk, to_person.pk)))

    assert "error" in response.context


def test_tree_from_to_renders_tree_for_valid_chain(client, make_person):
    grandparent = make_person(name="Grandparent")
    parent = make_person(name="Parent", parent=grandparent)
    person = make_person(name="Person", parent=parent)
    response = client.get(reverse("main:tree_from_to", args=(grandparent.pk, person.pk)))
    assert response.status_code == 200
    assert "error" not in response.context
    assert response.context["main_id"] == person.pk
    data = json.loads(response.context["data"])
    ids = {node["id"] for node in data}
    assert {grandparent.pk, parent.pk, person.pk}.issubset(ids)


def test_tree_from_to_same_person_returns_single_node(client, make_person):
    person = make_person(name="Solo")
    response = client.get(reverse("main:tree_from_to", args=(person.pk, person.pk)))
    assert response.status_code == 200
    assert "error" not in response.context
    data = json.loads(response.context["data"])
    assert len(data) == 1
    assert json.loads(response.context["links"]) == []


def test_tree_from_to_errors_when_no_route_exists(client, make_person):
    from_person = make_person(name="From")
    unrelated_root = make_person(name="UnrelatedRoot")
    unrelated_child = make_person(name="UnrelatedChild", parent=unrelated_root)
    response = client.get(reverse("main:tree_from_to", args=(from_person.pk, unrelated_child.pk)))
    assert "error" in response.context


# ---------------------------------------------------------------------------
# edit
# ---------------------------------------------------------------------------


def test_edit_view_renders_form_with_initial_data(client, staff_user, make_person):
    parent = make_person(name="Parent")
    person = make_person(name="Person", parent=parent, designation="Leader")
    make_person(name="Child", parent=person)
    client.force_login(staff_user)

    response = client.get(reverse("main:edit", args=(person.pk, parent.pk)))

    assert response.status_code == 200
    form = response.context["form"]
    assert form.initial["name"] == "Person"
    assert form.initial["children"] == "Child"
    assert response.context["orig_id"] == parent.pk


def test_edit_view_only_lists_children_editable_by_user(client, normal_user, other_user, make_person):
    person = make_person(name="Person", access="private", editors=[normal_user])
    make_person(name="VisibleChild", parent=person, access="private", editors=[normal_user])
    make_person(name="HiddenChild", parent=person, access="private", editors=[other_user])
    client.force_login(normal_user)

    response = client.get(reverse("main:edit", args=(person.pk, person.pk)))

    children_str = response.context["form"].initial["children"]
    assert "VisibleChild" in children_str
    assert "HiddenChild" not in children_str


# ---------------------------------------------------------------------------
# save
# ---------------------------------------------------------------------------


def post_save(client, orig_id, person_id, *, children="", name="Person", designation="", history=""):
    return client.post(
        reverse("main:save", args=(orig_id, person_id)),
        data={"children": children, "name": name, "designation": designation, "history": history},
    )


def test_save_creates_children_as_public_for_staff(client, staff_user, make_person):
    person = make_person(name="Person")
    client.force_login(staff_user)

    response = post_save(client, person.pk, person.pk, children="NewChild", name="Person")

    new_child = person.children.get(name="NewChild")
    assert new_child.access == "public"
    assert staff_user in new_child.editors.all()
    assert response.status_code == 302
    assert response.url == reverse("main:person_tree", args=(person.pk,))


def test_save_creates_children_as_private_for_normal_user(client, normal_user, make_person):
    person = make_person(name="Person", access="private", editors=[normal_user])
    client.force_login(normal_user)

    post_save(client, person.pk, person.pk, children="NewChild", name="Person")

    new_child = person.children.get(name="NewChild")
    assert new_child.access == "private"
    assert normal_user in new_child.editors.all()


def test_save_does_not_duplicate_existing_children(client, staff_user, make_person):
    person = make_person(name="Person")
    existing_child = make_person(name="ExistingChild", parent=person)
    client.force_login(staff_user)

    post_save(client, person.pk, person.pk, children="ExistingChild", name="Person")

    assert person.children.filter(name="ExistingChild").count() == 1
    existing_child.refresh_from_db()
    assert staff_user in existing_child.editors.all()


def test_save_updates_person_fields_for_editor(client, normal_user, make_person):
    person = make_person(name="OldName", access="private", editors=[normal_user])
    client.force_login(normal_user)

    post_save(client, person.pk, person.pk, name="NewName", designation="Lead", history="Some history")

    person.refresh_from_db()
    assert person.name == "NewName"
    assert person.designation == "Lead"
    assert person.history == "Some history"


def test_save_does_not_update_fields_for_non_editor(client, normal_user, other_user, make_person):
    person = make_person(name="OldName", access="private", editors=[other_user])
    client.force_login(normal_user)

    post_save(client, person.pk, person.pk, name="NewName")

    person.refresh_from_db()
    assert person.name == "OldName"


def test_save_anonymous_user_does_not_create_children_or_update_fields(client, make_person):
    person = make_person(name="OldName", access="public")

    post_save(client, person.pk, person.pk, children="NewChild", name="NewName")

    assert person.children.count() == 0
    person.refresh_from_db()
    assert person.name == "OldName"


# ---------------------------------------------------------------------------
# undo_choose / undo_do
# ---------------------------------------------------------------------------


def test_undo_choose_lists_backups(client, db, monkeypatch):
    fake_files = [pathlib.Path("/tmp/dummy_db-20240102151413.sqlite3")]
    monkeypatch.setattr("main.views.list_backups", lambda: fake_files)

    response = client.get(reverse("main:undo_choose"))

    assert response.status_code == 200
    assert response.context["file_names"] == ["dummy_db-20240102151413.sqlite3"]
    assert response.context["files_str"] == ["2024/01/02 - 15:14:13"]


def test_undo_do_restores_backup_for_staff_user(client, staff_user, monkeypatch):
    fake_files = [pathlib.Path("/tmp/dummy_db-20240102151413.sqlite3")]
    calls = []
    generate_calls = []
    monkeypatch.setattr("main.views.list_backups", lambda: fake_files)
    monkeypatch.setattr("main.views.subprocess.call", lambda cmd, shell=False: calls.append(cmd))
    monkeypatch.setattr("main.views.generate_home_tree", lambda: generate_calls.append(True))
    client.force_login(staff_user)

    response = client.get(reverse("main:undo_do", args=(0,)))

    assert response.status_code == 302
    assert response.url == "/"
    assert len(calls) == 1
    assert "dummy_db-20240102151413.sqlite3" in calls[0]
    assert generate_calls == [True]


def test_undo_do_does_nothing_for_non_staff_user(client, normal_user, monkeypatch):
    calls = []
    monkeypatch.setattr("main.views.list_backups", lambda: (_ for _ in ()).throw(AssertionError("should not be called")))
    monkeypatch.setattr("main.views.subprocess.call", lambda cmd, shell=False: calls.append(cmd))
    client.force_login(normal_user)

    response = client.get(reverse("main:undo_do", args=(0,)))

    assert response.status_code == 302
    assert response.url == "/"
    assert calls == []


# ---------------------------------------------------------------------------
# tos / test
# ---------------------------------------------------------------------------


def test_tos_view_renders(client, db):
    response = client.get(reverse("main:tos"))
    assert response.status_code == 200


def test_test_view_logs_and_renders(client, db, caplog):
    with caplog.at_level(logging.INFO):
        response = client.get(reverse("main:test"))
    assert response.status_code == 200
    assert "Hello" in caplog.text


# ---------------------------------------------------------------------------
# settingsPanel
# ---------------------------------------------------------------------------


def test_settings_panel_shows_message_for_anonymous_user(client, db):
    response = client.get(reverse("main:settingsPanel"))
    assert response.status_code == 200
    assert "not logged in" in response.content.decode().lower()


def test_settings_panel_get_renders_form_for_authenticated_user(client, normal_user):
    client.force_login(normal_user)

    response = client.get(reverse("main:settingsPanel"))

    assert response.status_code == 200
    assert response.context["form"].instance == normal_user


def test_settings_panel_post_updates_user_and_redirects(client, normal_user):
    client.force_login(normal_user)

    response = client.post(
        reverse("main:settingsPanel"),
        data={
            "first_name": "Jane",
            "father_name": "John",
            "grandfather_name": "Jack",
            "last_name": "Doe",
            "birth_date": "1990-01-01",
            "birth_place": "City",
        },
    )

    assert response.status_code == 302
    assert response.url == "/"
    normal_user.refresh_from_db()
    assert normal_user.first_name == "Jane"
    assert normal_user.birth_place == "City"


def test_settings_panel_post_invalid_data_rerenders_form(client, normal_user):
    client.force_login(normal_user)

    response = client.post(reverse("main:settingsPanel"), data={})

    assert response.status_code == 200
    assert response.context["form"].errors


# ---------------------------------------------------------------------------
# delete_user
# ---------------------------------------------------------------------------


def test_delete_user_deletes_authenticated_user(client, normal_user):
    client.force_login(normal_user)
    user_pk = normal_user.pk

    response = client.get(reverse("main:delete_user"))

    assert response.status_code == 302
    assert response.url == "/"
    assert not User.objects.filter(pk=user_pk).exists()


def test_delete_user_anonymous_just_redirects(client, db):
    response = client.get(reverse("main:delete_user"))
    assert response.status_code == 302
    assert response.url == "/"


# ---------------------------------------------------------------------------
# changes
# ---------------------------------------------------------------------------


def test_changes_lists_only_private_persons(client, make_person):
    private_person = make_person(name="Private", access="private")
    make_person(name="Public", access="public")

    response = client.get(reverse("main:changes"))

    assert response.status_code == 200
    assert response.context["changes"] == [private_person]
