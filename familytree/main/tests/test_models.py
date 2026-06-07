import pytest
from django.contrib.auth.models import AnonymousUser

from main.models import N_COLORS, Person

# ---------------------------------------------------------------------------
# Person.is_visible_to
# ---------------------------------------------------------------------------


def test_is_visible_to_public_person_visible_to_anyone(make_person, normal_user, staff_user):
    person = make_person(access="public")
    assert person.is_visible_to(normal_user) is True
    assert person.is_visible_to(staff_user) is True
    assert person.is_visible_to(AnonymousUser()) is True


def test_is_visible_to_private_person_visible_to_staff(make_person, staff_user):
    person = make_person(access="private")
    assert person.is_visible_to(staff_user) is True


def test_is_visible_to_private_person_visible_to_editor(make_person, normal_user):
    person = make_person(access="private", editors=[normal_user])
    assert person.is_visible_to(normal_user) is True


def test_is_visible_to_private_person_not_visible_to_stranger(make_person, normal_user, other_user):
    person = make_person(access="private", editors=[other_user])
    assert person.is_visible_to(normal_user) is False


# ---------------------------------------------------------------------------
# Person.is_editable_by
# ---------------------------------------------------------------------------


def test_is_editable_by_staff_can_edit_anything(make_person, staff_user):
    public_person = make_person(name="Public", access="public")
    private_person = make_person(name="Private", access="private")
    assert public_person.is_editable_by(staff_user) is True
    assert private_person.is_editable_by(staff_user) is True


def test_is_editable_by_public_person_not_editable_by_non_staff(make_person, normal_user):
    person = make_person(access="public", editors=[normal_user])
    assert person.is_editable_by(normal_user) is False


def test_is_editable_by_sole_editor_can_edit(make_person, normal_user):
    person = make_person(access="private", editors=[normal_user])
    assert person.is_editable_by(normal_user) is True


def test_is_editable_by_one_of_many_editors_cannot_edit(make_person, normal_user, other_user):
    person = make_person(access="private", editors=[normal_user, other_user])
    assert person.is_editable_by(normal_user) is False


def test_is_editable_by_non_editor_cannot_edit(make_person, normal_user, other_user):
    person = make_person(access="private", editors=[other_user])
    assert person.is_editable_by(normal_user) is False


# ---------------------------------------------------------------------------
# Person.expand
# ---------------------------------------------------------------------------


@pytest.fixture
def chain(make_person):
    """A linear chain of 4 generations: p0 -> p1 -> p2 -> p3"""
    p0 = make_person(name="Gen0")
    p1 = make_person(name="Gen1", parent=p0)
    p2 = make_person(name="Gen2", parent=p1)
    p3 = make_person(name="Gen3", parent=p2)
    return [p0, p1, p2, p3]


def test_expand_returns_depth_plus_one_levels(chain):
    p0, p1, p2, p3 = chain
    levels = p0.expand(depth=2)
    assert levels == [[p0], [p1], [p2]]


def test_expand_depth_zero_returns_only_self(chain):
    p0, *_ = chain
    assert p0.expand(depth=0) == [[p0]]


def test_expand_stops_when_no_more_children(chain):
    *_, p3 = chain
    assert p3.expand(depth=5) == [[p3]]


def test_expand_includes_all_children_in_a_level(make_person):
    root = make_person(name="Root")
    child_a = make_person(name="ChildA", parent=root)
    child_b = make_person(name="ChildB", parent=root)
    levels = root.expand(depth=1)
    assert levels[0] == [root]
    assert set(levels[1]) == {child_a, child_b}


# ---------------------------------------------------------------------------
# Person.get_grandfather
# ---------------------------------------------------------------------------


def test_get_grandfather_returns_none_when_no_parent(make_person):
    person = make_person()
    assert person.get_grandfather() is None


def test_get_grandfather_returns_none_when_parent_has_no_parent(make_person):
    grandparent = make_person(name="Grandparent")
    parent = make_person(name="Parent", parent=grandparent)
    assert parent.get_grandfather() is None


def test_get_grandfather_returns_grandparent(chain):
    p0, p1, p2, _ = chain
    assert p2.get_grandfather() == p0


# ---------------------------------------------------------------------------
# Person.__str__ (and _get_father)
# ---------------------------------------------------------------------------


def test_str_with_no_parent(make_person):
    person = make_person(name="Alice")
    assert str(person) == "Alice "


def test_str_includes_ancestors_names(make_person):
    grandparent = make_person(name="Carol")
    parent = make_person(name="Bob", parent=grandparent)
    person = make_person(name="Alice", parent=parent)
    assert str(person) == "Alice Bob Carol "


def test_str_truncates_after_six_generations(make_person):
    names = ["P0", "P1", "P2", "P3", "P4", "P5", "P6", "P7"]
    parent = None
    persons = []
    for name in names:
        parent = make_person(name=name, parent=parent)
        persons.append(parent)
    # _get_father is called with depth=6, so the name plus at most 5 ancestor names are included
    assert str(persons[-1]) == "P7 P6 P5 P4 P3 P2 "


# ---------------------------------------------------------------------------
# Person.is_public / is_bookmarked
# ---------------------------------------------------------------------------


def test_is_public(make_person):
    assert make_person(access="public").is_public() is True
    assert make_person(access="private").is_public() is False


def test_is_bookmarked(make_person):
    from home.models import Bookmark

    person = make_person()
    assert person.is_bookmarked() is False

    Bookmark.objects.create(person=person)
    refreshed = Person.objects.get(pk=person.pk)
    assert refreshed.is_bookmarked() is True


# ---------------------------------------------------------------------------
# Person.as_node
# ---------------------------------------------------------------------------


def test_as_node_default_group_based_on_parent(make_person):
    parent = make_person(name="Parent")
    child = make_person(name="Child", parent=parent)
    node = child.as_node()
    assert node["group"] == f"g{parent.pk % N_COLORS}"


def test_as_node_root_group_is_g0(make_person):
    root = make_person(name="Root")
    node = root.as_node()
    assert node["group"] == "g0"


def test_as_node_forced_group(make_person):
    person = make_person()
    node = person.as_node(forced_group=2)
    assert node["group"] == "g2"


def test_as_node_opacity_for_anonymous_or_non_staff(make_person, normal_user):
    person = make_person(access="private")
    assert person.as_node(user=None)["opacity"] == 1.0
    assert person.as_node(user=normal_user)["opacity"] == 1.0


def test_as_node_opacity_for_staff(make_person, staff_user):
    public_person = make_person(name="Public", access="public")
    private_person = make_person(name="Private", access="private")
    assert public_person.as_node(user=staff_user)["opacity"] == 1.0
    assert private_person.as_node(user=staff_user)["opacity"] == 0.3


def test_as_node_omits_title_when_no_designation_or_history(make_person):
    person = make_person()
    node = person.as_node()
    assert "title" not in node
    assert "font" not in node


def test_as_node_includes_title_when_designation_present(make_person):
    person = make_person()
    person.designation = "Leader"
    person.save()
    node = person.as_node()
    assert node["title"] == "Leader\n"
    assert node["font"] == {"strokeWidth": 5}


# ---------------------------------------------------------------------------
# Person.find_closest_parent
# ---------------------------------------------------------------------------


def test_find_closest_parent_finds_immediate_parent(chain):
    p0, p1, p2, _ = chain
    parent, length = p2.find_closest_parent([p0, p1])
    assert parent == p1
    assert length == 1


def test_find_closest_parent_skips_to_further_ancestor(chain):
    p0, p1, p2, _ = chain
    parent, length = p2.find_closest_parent([p0])
    assert parent == p0
    assert length == 2


def test_find_closest_parent_returns_none_when_not_found(chain, make_person):
    p0, p1, p2, _ = chain
    unrelated = make_person(name="Unrelated")
    parent, length = p2.find_closest_parent([unrelated])
    assert parent is None
    assert length == -1


# ---------------------------------------------------------------------------
# Person.remove_editor
# ---------------------------------------------------------------------------


def test_remove_editor_removes_non_sole_editor(make_person, normal_user, other_user):
    person = make_person(access="private", editors=[normal_user, other_user])
    person.remove_editor(normal_user)
    assert normal_user not in person.editors.all()
    assert other_user in person.editors.all()


def test_remove_editor_keeps_sole_staff_editor(make_person, staff_user):
    person = make_person(access="private", editors=[staff_user])
    person.remove_editor(staff_user)
    assert staff_user in person.editors.all()


def test_remove_editor_removes_sole_non_staff_editor(make_person, normal_user):
    person = make_person(access="private", editors=[normal_user])
    person.remove_editor(normal_user)
    assert normal_user not in person.editors.all()


# ---------------------------------------------------------------------------
# User.user_type
# ---------------------------------------------------------------------------


def test_user_type_for_superuser(db):
    from main.models import User

    user = User.objects.create_superuser(username="root", email="root@example.com", password="pw")
    assert user.user_type == "Staff"


def test_user_type_for_staff(staff_user):
    assert staff_user.user_type == "Staff"


def test_user_type_for_normal_user(normal_user):
    assert normal_user.user_type == "normal"


def test_user_type_anonymous_branch_is_unreachable_for_real_users(normal_user):
    # AbstractBaseUser.is_authenticated is always True for saved model instances,
    # so the "Anonymous" branch of user_type can never be reached through User.
    assert normal_user.is_authenticated is True
    assert normal_user.user_type != "Anonymous"
