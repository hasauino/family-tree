from types import SimpleNamespace

import pytest
from django.contrib.auth.models import AnonymousUser
from home.models import Bookmark

from main.graphql.schema import (
    AddPerson,
    BookmarkPerson,
    DeletePerson,
    EditBookmark,
    EditPerson,
    MutationReply,
    PublishPerson,
    Query,
    RestoreBackup,
    UnBookmarkPerson,
    UnPublishPerson,
    authenticated_only,
    staff_only,
)
from main.graphql.types import PersonType
from main.models import Person


def info_for(user):
    return SimpleNamespace(context=SimpleNamespace(user=user))


# ---------------------------------------------------------------------------
# decorators
# ---------------------------------------------------------------------------


def test_authenticated_only_blocks_anonymous_users():
    fn = authenticated_only(lambda root, info: "ok")
    with pytest.raises(Exception, match="Access Denied"):
        fn(None, info_for(AnonymousUser()))


def test_authenticated_only_allows_authenticated_users(normal_user):
    fn = authenticated_only(lambda root, info: "ok")
    assert fn(None, info_for(normal_user)) == "ok"


def test_staff_only_blocks_non_staff_users(normal_user):
    fn = staff_only(lambda root, info: "ok")
    with pytest.raises(Exception, match="Access Denied"):
        fn(None, info_for(normal_user))


def test_staff_only_allows_staff_users(staff_user):
    fn = staff_only(lambda root, info: "ok")
    assert fn(None, info_for(staff_user)) == "ok"


# ---------------------------------------------------------------------------
# MutationReply
# ---------------------------------------------------------------------------


def test_mutation_reply_success():
    assert MutationReply.success("done") == {"ok": True, "message": "done"}


def test_mutation_reply_fail():
    assert MutationReply.fail("nope") == {"ok": False, "message": "nope"}


# ---------------------------------------------------------------------------
# Query.resolve_connected_nodes
# ---------------------------------------------------------------------------


def test_resolve_connected_nodes_returns_parent_and_children(make_person):
    grandparent = make_person(name="Grandparent")
    parent = make_person(name="Parent", parent=grandparent)
    child1 = make_person(name="Child1", parent=parent)
    child2 = make_person(name="Child2", parent=parent)

    result = Query.resolve_connected_nodes(None, info_for(AnonymousUser()), id=parent.pk)

    assert result["parent"]["id"] == grandparent.pk
    assert {child["id"] for child in result["children"]} == {child1.pk, child2.pk}


def test_resolve_connected_nodes_hides_invisible_parent(make_person):
    parent = make_person(name="Parent", access="private")
    person = make_person(name="Person", parent=parent)

    result = Query.resolve_connected_nodes(None, info_for(AnonymousUser()), id=person.pk)

    assert result["parent"] is None


def test_resolve_connected_nodes_filters_invisible_children(make_person, normal_user, other_user):
    person = make_person(name="Person")
    visible_child = make_person(name="VisibleChild", parent=person, access="private", editors=[normal_user])
    make_person(name="HiddenChild", parent=person, access="private", editors=[other_user])

    result = Query.resolve_connected_nodes(None, info_for(normal_user), id=person.pk)

    assert {child["id"] for child in result["children"]} == {visible_child.pk}


def test_connected_nodes_report_child_count_and_has_parent(make_person, normal_user, other_user):
    grandparent = make_person(name="Grandparent")
    parent = make_person(name="Parent", parent=grandparent)
    make_person(name="VisibleChild", parent=parent, access="private", editors=[normal_user])
    make_person(name="HiddenChild", parent=parent, access="private", editors=[other_user])

    result = Query.resolve_connected_nodes(None, info_for(normal_user), id=parent.pk)

    # The returned parent is the grandparent: it has one visible child (`parent`)
    # and no parent of its own.
    assert result["parent"]["child_count"] == 1
    assert result["parent"]["has_parent"] is False

    # The visible child reports a visible parent and (hidden) no children.
    visible_child = next(c for c in result["children"] if c["label"] == "VisibleChild")
    assert visible_child["child_count"] == 0
    assert visible_child["has_parent"] is True


def test_node_has_parent_false_when_parent_hidden(make_person):
    hidden_parent = make_person(name="Hidden", access="private")
    person = make_person(name="Person", parent=hidden_parent)

    node = person.as_node(AnonymousUser())

    assert node["has_parent"] is False


# ---------------------------------------------------------------------------
# Query.resolve_person
# ---------------------------------------------------------------------------


def test_resolve_person_returns_person_by_id(make_person):
    person = make_person(name="Alice")
    assert Query.resolve_person(None, info_for(AnonymousUser()), id=person.pk) == person


# ---------------------------------------------------------------------------
# Query.resolve_tree_path
# ---------------------------------------------------------------------------


def test_resolve_tree_path_returns_chain_with_siblings_and_edges(make_person):
    grandparent = make_person(name="Grandparent")
    parent = make_person(name="Parent", parent=grandparent)
    child1 = make_person(name="Child1", parent=parent)
    child2 = make_person(name="Child2", parent=parent)
    grandchild = make_person(name="Grandchild", parent=child1)

    result = Query.resolve_tree_path(None, info_for(AnonymousUser()), from_id=grandparent.pk, to_id=grandchild.pk)

    assert [n["id"] for n in result["nodes"]] == [
        grandparent.pk,
        parent.pk,
        child1.pk,
        child2.pk,
        grandchild.pk,
    ]
    assert {(e["from_id"], e["to_id"]) for e in result["edges"]} == {
        (grandparent.pk, parent.pk),
        (parent.pk, child1.pk),
        (parent.pk, child2.pk),
        (child1.pk, grandchild.pk),
    }
    assert result["path_ids"] == [grandparent.pk, parent.pk, child1.pk, grandchild.pk]
    assert result["meeting_id"] == grandparent.pk
    assert result["from_generations"] == 0
    assert result["to_generations"] == 3
    assert result["is_direct"] is True


def test_resolve_tree_path_returns_single_node_when_endpoints_match(make_person):
    person = make_person(name="Solo")

    result = Query.resolve_tree_path(None, info_for(AnonymousUser()), from_id=person.pk, to_id=person.pk)

    assert [n["id"] for n in result["nodes"]] == [person.pk]
    assert result["edges"] == []
    assert result["path_ids"] == [person.pk]
    assert result["meeting_id"] == person.pk
    assert result["from_generations"] == 0
    assert result["to_generations"] == 0
    assert result["is_direct"] is True


def test_resolve_tree_path_meets_at_common_ancestor_when_neither_is_an_ancestor(make_person):
    root = make_person(name="Root")
    branch_a = make_person(name="BranchA", parent=root)
    branch_b = make_person(name="BranchB", parent=root)

    result = Query.resolve_tree_path(None, info_for(AnonymousUser()), from_id=branch_a.pk, to_id=branch_b.pk)

    assert result["meeting_id"] == root.pk
    assert result["from_generations"] == 1
    assert result["to_generations"] == 1
    assert result["is_direct"] is False
    assert result["path_ids"] == [branch_a.pk, root.pk, branch_b.pk]
    assert {(e["from_id"], e["to_id"]) for e in result["edges"]} == {
        (root.pk, branch_a.pk),
        (root.pk, branch_b.pk),
    }


def test_resolve_tree_path_returns_none_when_trees_are_disconnected(make_person):
    root_a = make_person(name="RootA")
    root_b = make_person(name="RootB")

    result = Query.resolve_tree_path(None, info_for(AnonymousUser()), from_id=root_a.pk, to_id=root_b.pk)

    assert result is None


def test_resolve_tree_path_returns_none_for_missing_person(make_person):
    person = make_person(name="Person")

    assert Query.resolve_tree_path(None, info_for(AnonymousUser()), from_id=999, to_id=person.pk) is None
    assert Query.resolve_tree_path(None, info_for(AnonymousUser()), from_id=person.pk, to_id=999) is None


def test_resolve_tree_path_returns_none_when_an_ancestor_is_invisible(make_person, normal_user, other_user):
    grandparent = make_person(name="Grandparent")
    hidden_parent = make_person(name="HiddenParent", parent=grandparent, access="private", editors=[other_user])
    person = make_person(name="Person", parent=hidden_parent)

    result = Query.resolve_tree_path(None, info_for(normal_user), from_id=grandparent.pk, to_id=person.pk)

    assert result is None


# ---------------------------------------------------------------------------
# Query.resolve_search_persons
# ---------------------------------------------------------------------------


def test_resolve_search_persons_matches_name_and_ancestors(make_person):
    grandparent = make_person(name="Carol")
    parent = make_person(name="Bob", parent=grandparent)
    person = make_person(name="Alice", parent=parent)

    results = Query.resolve_search_persons(None, info_for(AnonymousUser()), query="Alice Bob")

    assert {"id": person.id, "name": str(person)} in results


def test_resolve_search_persons_excludes_invisible_persons(make_person, normal_user, other_user):
    visible = make_person(name="Visible", access="private", editors=[normal_user])
    make_person(name="VisibleSecret", access="private", editors=[other_user])

    results = Query.resolve_search_persons(None, info_for(normal_user), query="Visible")

    assert results == [{"id": visible.id, "name": str(visible)}]


def test_resolve_search_persons_limits_results(make_person):
    for i in range(8):
        make_person(name=f"Match{i}")

    results = Query.resolve_search_persons(None, info_for(AnonymousUser()), query="Match")

    assert len(results) <= 6


# ---------------------------------------------------------------------------
# Query.resolve_can_delete
# ---------------------------------------------------------------------------


def test_resolve_can_delete_requires_authentication(make_person):
    person = make_person(name="Person")
    with pytest.raises(Exception, match="Access Denied"):
        Query.resolve_can_delete(None, info_for(AnonymousUser()), id=person.pk)


def test_resolve_can_delete_returns_editability(make_person, normal_user):
    person = make_person(name="Person", access="private", editors=[normal_user])
    assert Query.resolve_can_delete(None, info_for(normal_user), id=person.pk) is True


# ---------------------------------------------------------------------------
# Query.resolve_list_bookmarks
# ---------------------------------------------------------------------------


def test_resolve_list_bookmarks_requires_authentication(db):
    with pytest.raises(Exception, match="Access Denied"):
        Query.resolve_list_bookmarks(None, info_for(AnonymousUser()))


def test_resolve_list_bookmarks_returns_all_bookmarks(make_person, normal_user):
    person = make_person(name="Person")
    bookmark = Bookmark.objects.create(person=person)

    assert list(Query.resolve_list_bookmarks(None, info_for(normal_user))) == [bookmark]


# ---------------------------------------------------------------------------
# AddPerson
# ---------------------------------------------------------------------------


def test_edit_person_requires_authentication(make_person):
    person = make_person(name="Parent")
    with pytest.raises(Exception, match="Access Denied"):
        EditPerson.mutate(None, info_for(AnonymousUser()), id=person.pk, name="New")


def test_edit_person_fails_for_missing_person(staff_user, db):
    result = EditPerson.mutate(None, info_for(staff_user), id=999999, name="New")
    assert result["ok"] is False


def test_edit_person_rejects_empty_name(staff_user, make_person):
    person = make_person(name="Parent")
    result = EditPerson.mutate(None, info_for(staff_user), id=person.pk, name="")
    assert result["ok"] is False


def test_edit_person_blocks_non_editor(normal_user, make_person):
    person = make_person(name="Parent", access="public")
    result = EditPerson.mutate(None, info_for(normal_user), id=person.pk, name="New")
    assert result["ok"] is False


def test_edit_person_updates_fields_for_staff(staff_user, make_person):
    person = make_person(name="Old", designation="d", history="h")

    result = EditPerson.mutate(
        None,
        info_for(staff_user),
        id=person.pk,
        name="New",
        designation="dd",
        history="hh",
    )

    person.refresh_from_db()
    assert result["ok"] is True
    assert result["label"] == "New"
    assert (person.name, person.designation, person.history) == ("New", "dd", "hh")


def test_edit_person_allows_editor_of_private_person(normal_user, make_person):
    person = make_person(name="Old", access="private", editors=[normal_user])

    result = EditPerson.mutate(None, info_for(normal_user), id=person.pk, name="New")

    person.refresh_from_db()
    assert result["ok"] is True
    assert person.name == "New"


def test_edit_person_keeps_unspecified_fields(staff_user, make_person):
    person = make_person(name="Old", designation="keep", history="keep-too")

    EditPerson.mutate(None, info_for(staff_user), id=person.pk, name="New")

    person.refresh_from_db()
    assert (person.designation, person.history) == ("keep", "keep-too")


def test_add_person_requires_authentication(make_person):
    person = make_person(name="Parent")
    with pytest.raises(Exception, match="Access Denied"):
        AddPerson.mutate(None, info_for(AnonymousUser()), id=person.pk, child_name="Child")


def test_add_person_rejects_empty_name(normal_user, make_person):
    person = make_person(name="Parent")
    result = AddPerson.mutate(None, info_for(normal_user), id=person.pk, child_name="")
    assert result["ok"] is False


def test_add_person_fails_for_missing_parent(normal_user, db):
    result = AddPerson.mutate(None, info_for(normal_user), id=999999, child_name="Child")
    assert result["ok"] is False


def test_add_person_creates_private_child_for_normal_user(normal_user, make_person):
    person = make_person(name="Parent")

    result = AddPerson.mutate(None, info_for(normal_user), id=person.pk, child_name="NewChild")

    child = person.children.get(name="NewChild")
    assert child.access == "private"
    assert normal_user in child.editors.all()
    assert result["ok"] is True
    assert result["label"] == "NewChild"


def test_add_person_creates_public_child_for_staff(staff_user, make_person):
    person = make_person(name="Parent")

    AddPerson.mutate(None, info_for(staff_user), id=person.pk, child_name="NewChild")

    child = person.children.get(name="NewChild")
    assert child.access == "public"


def test_add_person_reuses_existing_child(normal_user, make_person):
    person = make_person(name="Parent")
    existing = make_person(name="ExistingChild", parent=person)

    AddPerson.mutate(None, info_for(normal_user), id=person.pk, child_name="ExistingChild")

    assert person.children.filter(name="ExistingChild").count() == 1
    existing.refresh_from_db()
    assert normal_user in existing.editors.all()


# ---------------------------------------------------------------------------
# DeletePerson
# ---------------------------------------------------------------------------


def test_delete_person_requires_authentication(make_person):
    person = make_person(name="Person")
    with pytest.raises(Exception, match="Access Denied"):
        DeletePerson.mutate(None, info_for(AnonymousUser()), id=person.pk)


def test_delete_person_fails_for_missing_person(normal_user, db):
    result = DeletePerson.mutate(None, info_for(normal_user), id=999999)
    assert result["ok"] is False


def test_delete_person_fails_when_not_editable(normal_user, other_user, make_person):
    person = make_person(name="Person", access="private", editors=[other_user])

    result = DeletePerson.mutate(None, info_for(normal_user), id=person.pk)

    assert result["ok"] is False
    assert Person.objects.filter(pk=person.pk).exists()


def test_delete_person_staff_deletes_outright(staff_user, make_person):
    person = make_person(name="Person")

    result = DeletePerson.mutate(None, info_for(staff_user), id=person.pk)

    assert result["ok"] is True
    assert not Person.objects.filter(pk=person.pk).exists()


def test_delete_person_sole_editor_deletes_private_person(normal_user, make_person):
    person = make_person(name="Person", access="private", editors=[normal_user])

    result = DeletePerson.mutate(None, info_for(normal_user), id=person.pk)

    assert result["ok"] is True
    assert not Person.objects.filter(pk=person.pk).exists()


def test_delete_person_one_of_many_editors_only_loses_editor_access(normal_user, other_user, make_person):
    person = make_person(name="Person", access="private", editors=[normal_user, other_user])

    result = DeletePerson.mutate(None, info_for(normal_user), id=person.pk)

    assert result["ok"] is False
    person.refresh_from_db()
    assert normal_user in person.editors.all()


# ---------------------------------------------------------------------------
# BookmarkPerson / UnBookmarkPerson
# ---------------------------------------------------------------------------


def test_bookmark_person_requires_staff(normal_user, make_person):
    person = make_person(name="Person")
    with pytest.raises(Exception, match="Access Denied"):
        BookmarkPerson.mutate(None, info_for(normal_user), id=person.pk)


def test_bookmark_person_fails_for_missing_person(staff_user, db):
    result = BookmarkPerson.mutate(None, info_for(staff_user), id=999999)
    assert result["ok"] is False


def test_bookmark_person_fails_for_private_person(staff_user, make_person):
    person = make_person(name="Person", access="private")

    result = BookmarkPerson.mutate(None, info_for(staff_user), id=person.pk)

    assert result["ok"] is False
    assert not Bookmark.objects.filter(person=person).exists()


def test_bookmark_person_creates_bookmark_for_public_person(staff_user, make_person):
    person = make_person(name="Person", access="public")

    result = BookmarkPerson.mutate(None, info_for(staff_user), id=person.pk)

    assert result["ok"] is True
    assert Bookmark.objects.filter(person=person).exists()


def test_bookmark_person_is_idempotent(staff_user, make_person):
    person = make_person(name="Person", access="public")

    BookmarkPerson.mutate(None, info_for(staff_user), id=person.pk)
    BookmarkPerson.mutate(None, info_for(staff_user), id=person.pk)

    assert Bookmark.objects.filter(person=person).count() == 1


def test_unbookmark_person_requires_staff(normal_user, make_person):
    person = make_person(name="Person")
    with pytest.raises(Exception, match="Access Denied"):
        UnBookmarkPerson.mutate(None, info_for(normal_user), id=person.pk)


def test_unbookmark_person_fails_for_missing_person(staff_user, db):
    result = UnBookmarkPerson.mutate(None, info_for(staff_user), id=999999)
    assert result["ok"] is False


def test_unbookmark_person_removes_bookmark(staff_user, make_person):
    person = make_person(name="Person", access="public")
    Bookmark.objects.create(person=person)

    result = UnBookmarkPerson.mutate(None, info_for(staff_user), id=person.pk)

    assert result["ok"] is True
    assert not Bookmark.objects.filter(person=person).exists()


# ---------------------------------------------------------------------------
# PublishPerson / UnPublishPerson
# ---------------------------------------------------------------------------


def test_publish_person_requires_staff(normal_user, make_person):
    person = make_person(name="Person", access="private")
    with pytest.raises(Exception, match="Access Denied"):
        PublishPerson.mutate(None, info_for(normal_user), id=person.pk)


def test_publish_person_fails_for_missing_person(staff_user, db):
    result = PublishPerson.mutate(None, info_for(staff_user), id=999999)
    assert result["ok"] is False


def test_publish_person_publishes_person_and_children(staff_user, make_person):
    person = make_person(name="Person", access="private")
    child = make_person(name="Child", parent=person, access="private")

    result = PublishPerson.mutate(None, info_for(staff_user), id=person.pk)

    person.refresh_from_db()
    child.refresh_from_db()
    assert result["ok"] is True
    assert person.access == "public"
    assert child.access == "public"
    assert staff_user in person.editors.all()
    assert staff_user in child.editors.all()


def test_unpublish_person_requires_staff(normal_user, make_person):
    person = make_person(name="Person", access="public")
    with pytest.raises(Exception, match="Access Denied"):
        UnPublishPerson.mutate(None, info_for(normal_user), id=person.pk)


def test_unpublish_person_fails_for_missing_person(staff_user, db):
    result = UnPublishPerson.mutate(None, info_for(staff_user), id=999999)
    assert result["ok"] is False


def test_unpublish_person_unpublishes_and_removes_bookmarks(staff_user, make_person):
    person = make_person(name="Person", access="public", editors=[staff_user])
    child = make_person(name="Child", parent=person, access="public", editors=[staff_user])
    Bookmark.objects.create(person=person)
    Bookmark.objects.create(person=child)

    result = UnPublishPerson.mutate(None, info_for(staff_user), id=person.pk)

    person.refresh_from_db()
    child.refresh_from_db()
    assert result["ok"] is True
    assert person.access == "private"
    assert child.access == "private"
    assert not Bookmark.objects.filter(person=person).exists()
    assert not Bookmark.objects.filter(person=child).exists()


# ---------------------------------------------------------------------------
# EditBookmark
# ---------------------------------------------------------------------------


def test_edit_bookmark_requires_staff(normal_user, make_person):
    person = make_person(name="Person", access="public")
    Bookmark.objects.create(person=person)
    with pytest.raises(Exception, match="Access Denied"):
        EditBookmark.mutate(None, info_for(normal_user), id=person.pk)


def test_edit_bookmark_updates_fields(staff_user, make_person):
    person = make_person(name="Person", access="public")
    Bookmark.objects.create(person=person)

    result = EditBookmark.mutate(
        None,
        info_for(staff_user),
        id=person.pk,
        label="Custom",
        color="ff0000",
        font_color="00ff00",
        font_size=20,
    )

    bookmark = Bookmark.objects.get(person=person)
    assert result["ok"] is True
    assert bookmark.label == "Custom"
    assert bookmark.color == "ff0000"
    assert bookmark.font_color == "00ff00"
    assert bookmark.font_size == 20


def test_edit_bookmark_resets_font_size_with_minus_one(staff_user, make_person):
    person = make_person(name="Person", access="public")
    bookmark = Bookmark.objects.create(person=person, font_size=20)

    EditBookmark.mutate(None, info_for(staff_user), id=person.pk, font_size=-1)

    bookmark.refresh_from_db()
    assert bookmark.font_size is None


# ---------------------------------------------------------------------------
# PersonType resolvers
# ---------------------------------------------------------------------------


def test_person_type_resolve_published(make_person):
    public_person = make_person(access="public")
    private_person = make_person(access="private")
    assert PersonType.resolve_published(public_person, None) is True
    assert PersonType.resolve_published(private_person, None) is False


def test_person_type_resolve_bookmarked(make_person):
    person = make_person()
    assert PersonType.resolve_bookmarked(person, None) is False

    Bookmark.objects.create(person=person)
    refreshed = Person.objects.get(pk=person.pk)
    assert PersonType.resolve_bookmarked(refreshed, None) is True


# ---------------------------------------------------------------------------
# Database restore (listBackups / RestoreBackup)
# ---------------------------------------------------------------------------

import pathlib  # noqa: E402
import sys  # noqa: E402

# The `main.graphql.schema` *attribute* resolves to the graphene Schema object
# (the module's `schema = graphene.Schema(...)` shadows the submodule on the
# package), so fetch the real module from sys.modules to patch its globals.
schema_module = sys.modules["main.graphql.schema"]


def test_resolve_list_backups_blocks_non_staff(normal_user):
    with pytest.raises(Exception, match="Access Denied"):
        Query.resolve_list_backups(None, info_for(normal_user))


def test_resolve_list_backups_labels_each_backup_for_staff(staff_user, monkeypatch):
    fake_files = [
        pathlib.Path("/tmp/db-20240102151413.sqlite3"),
        pathlib.Path("/tmp/db-20230101000000.sqlite3"),
    ]
    monkeypatch.setattr(schema_module, "list_backups", lambda: fake_files)

    result = Query.resolve_list_backups(None, info_for(staff_user))

    assert [(b.id, b.label) for b in result] == [
        (0, "2024/01/02 - 15:14:13"),
        (1, "2023/01/01 - 00:00:00"),
    ]


def test_restore_backup_blocks_non_staff(normal_user):
    with pytest.raises(Exception, match="Access Denied"):
        RestoreBackup.mutate(None, info_for(normal_user), id=0)


def test_restore_backup_copies_chosen_file_and_regenerates_home_tree(staff_user, monkeypatch):
    fake_files = [pathlib.Path("/tmp/db-20240102151413.sqlite3")]
    restored = []
    generated = []
    monkeypatch.setattr(schema_module, "list_backups", lambda: fake_files)
    monkeypatch.setattr(schema_module, "restore_backup", lambda f: restored.append(f))
    monkeypatch.setattr(schema_module, "generate_home_tree", lambda: generated.append(True))

    result = RestoreBackup.mutate(None, info_for(staff_user), id=0)

    assert result["ok"] is True
    assert restored == [fake_files[0]]
    assert generated == [True]


def test_restore_backup_rejects_out_of_range_id(staff_user, monkeypatch):
    monkeypatch.setattr(schema_module, "list_backups", lambda: [])
    monkeypatch.setattr(
        schema_module,
        "restore_backup",
        lambda f: (_ for _ in ()).throw(AssertionError("should not be called")),
    )

    result = RestoreBackup.mutate(None, info_for(staff_user), id=0)

    assert result["ok"] is False
