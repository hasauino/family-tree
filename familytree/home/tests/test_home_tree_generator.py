import json

import pytest

import home.home_tree_generator as tree_gen_module
from home.home_tree_generator import (
    calculate_link_width,
    find_common_root,
    generate_home_tree,
    get_bookmark_depth,
    get_tree,
)
from home.models import Bookmark


@pytest.fixture(autouse=True)
def reset_home_tree_cache(monkeypatch):
    monkeypatch.setattr(tree_gen_module, "_home_tree", None)


# ---------------------------------------------------------------------------
# get_tree
# ---------------------------------------------------------------------------


def test_get_tree_generates_when_not_cached(monkeypatch):
    sentinel = {"data": "[]", "links": "[]"}

    def fake_generate():
        tree_gen_module._home_tree = sentinel

    monkeypatch.setattr(tree_gen_module, "generate_home_tree", fake_generate)

    assert get_tree() is sentinel


def test_get_tree_returns_cached_tree_without_regenerating(monkeypatch):
    sentinel = {"data": "[]", "links": "[]"}
    monkeypatch.setattr(tree_gen_module, "_home_tree", sentinel)
    calls = []
    monkeypatch.setattr(tree_gen_module, "generate_home_tree", lambda: calls.append(True))

    assert get_tree() is sentinel
    assert calls == []


# ---------------------------------------------------------------------------
# generate_home_tree
# ---------------------------------------------------------------------------


def test_generate_home_tree_with_no_bookmarks_produces_empty_tree(db):
    generate_home_tree()

    assert tree_gen_module._home_tree == {"data": json.dumps([]), "links": json.dumps([])}


def test_generate_home_tree_with_single_root_bookmark_has_no_links(make_person):
    root = make_person(name="Root", access="public")
    Bookmark.objects.create(person=root)

    generate_home_tree()

    tree = tree_gen_module._home_tree
    data = json.loads(tree["data"])
    links = json.loads(tree["links"])
    assert [node["id"] for node in data] == [root.pk]
    assert links == []


def test_generate_home_tree_links_bookmarked_parent_and_child(make_person):
    root = make_person(name="Root", access="public")
    child = make_person(name="Child", parent=root, access="public")
    Bookmark.objects.create(person=root)
    Bookmark.objects.create(person=child)

    generate_home_tree()

    tree = tree_gen_module._home_tree
    data = json.loads(tree["data"])
    links = json.loads(tree["links"])
    assert {node["id"] for node in data} == {root.pk, child.pk}
    assert len(links) == 1
    assert links[0]["from"] == root.pk
    assert links[0]["to"] == child.pk
    assert links[0]["width"] == pytest.approx(10.0)


def test_generate_home_tree_uses_max_bookmark_depth_as_tree_depth(make_person):
    root = make_person(name="Root", access="public")
    parent = make_person(name="Parent", parent=root, access="public")
    child = make_person(name="Child", parent=parent, access="public")
    grandchild = make_person(name="Grandchild", parent=child, access="public")
    for person in (root, parent, child, grandchild):
        Bookmark.objects.create(person=person)

    generate_home_tree()

    links = {link["to"]: link for link in json.loads(tree_gen_module._home_tree["links"])}
    # tree_depth becomes 3 (max bookmark depth), so the deepest link interpolates to width_min
    # and the shallowest link to width_max - if tree_depth stayed at the default of 2 these would differ
    assert links[grandchild.pk]["width"] == pytest.approx(5.0)
    assert links[parent.pk]["width"] == pytest.approx(10.0)


def test_generate_home_tree_clamps_width_max_to_forty(make_person, monkeypatch):
    monkeypatch.setattr("home.signals.generate_home_tree", lambda: None)
    parent = None
    persons = []
    for i in range(59):
        person = make_person(name=f"P{i}", parent=parent, access="public")
        Bookmark.objects.create(person=person)
        persons.append(person)
        parent = person

    generate_home_tree()

    links = json.loads(tree_gen_module._home_tree["links"])
    assert len(links) == 58  # width_max = 58 * 0.7 = 40.6, clamped down to 40
    assert max(link["width"] for link in links) == pytest.approx(40.0)


def test_generate_home_tree_adds_synthetic_common_root_for_multiple_orphans(make_person):
    root = make_person(name="Root", access="public")
    child_a = make_person(name="A", parent=root, access="public")
    child_b = make_person(name="B", parent=root, access="public")
    Bookmark.objects.create(person=child_a)
    Bookmark.objects.create(person=child_b)

    generate_home_tree()

    tree = tree_gen_module._home_tree
    data = json.loads(tree["data"])
    links = json.loads(tree["links"])
    assert {node["id"] for node in data} == {root.pk, child_a.pk, child_b.pk}
    assert {link["from"] for link in links} == {root.pk}
    assert {link["to"] for link in links} == {child_a.pk, child_b.pk}


# ---------------------------------------------------------------------------
# find_common_root
# ---------------------------------------------------------------------------


def test_find_common_root_returns_shared_parent(make_person):
    root = make_person(name="Root")
    child_a = make_person(name="A", parent=root)
    child_b = make_person(name="B", parent=root)

    assert find_common_root([child_a, child_b]) == root


def test_find_common_root_returns_root_itself_when_included(make_person):
    root = make_person(name="Root")
    child = make_person(name="Child", parent=root)

    assert find_common_root([root, child]) == root


def test_find_common_root_returns_none_for_empty_list():
    assert find_common_root([]) is None


def test_find_common_root_handles_converging_paths_through_matched_nodes(make_person):
    """Exercises the "matched" bookkeeping branch: when a node and its own
    descendants are searched together, their upward walks converge on that
    node from multiple directions before any of them reaches the tree root."""
    great_grandparent = make_person(name="GreatGrandparent")
    grandparent = make_person(name="Grandparent", parent=great_grandparent)
    parent = make_person(name="Parent", parent=grandparent)
    child_a = make_person(name="ChildA", parent=parent)
    child_b = make_person(name="ChildB", parent=parent)

    assert find_common_root([parent, child_a, child_b]) == parent


# ---------------------------------------------------------------------------
# get_bookmark_depth
# ---------------------------------------------------------------------------


def test_get_bookmark_depth_is_zero_when_person_has_no_link(make_person):
    person = make_person(name="Person")
    assert get_bookmark_depth(person, {}) == 0


def test_get_bookmark_depth_counts_chain_of_links(make_person):
    grandparent = make_person(name="Grandparent")
    parent = make_person(name="Parent", parent=grandparent)
    child = make_person(name="Child", parent=parent)
    links = {
        parent.pk: {"id": parent.pk, "from": grandparent.pk, "to": parent.pk},
        child.pk: {"id": child.pk, "from": parent.pk, "to": child.pk},
    }

    assert get_bookmark_depth(child, links) == 2
    assert get_bookmark_depth(parent, links) == 1
    assert get_bookmark_depth(grandparent, links) == 0


# ---------------------------------------------------------------------------
# calculate_link_width
# ---------------------------------------------------------------------------


def test_calculate_link_width_at_shallowest_depth_is_max_width():
    assert calculate_link_width(width_min=5, width_max=10, tree_depth=2, link_depth=1) == pytest.approx(10.0)


def test_calculate_link_width_at_deepest_depth_is_min_width():
    assert calculate_link_width(width_min=5, width_max=10, tree_depth=4, link_depth=4) == pytest.approx(5.0)
