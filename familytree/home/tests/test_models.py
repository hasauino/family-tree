from home.models import Bookmark


def test_as_node_wraps_label_in_asterisks_and_drops_title(make_person):
    person = make_person(name="Person", designation="Leader", history="Some history")
    bookmark = Bookmark.objects.create(person=person)

    node = bookmark.as_node()

    assert "title" not in node
    assert node["label"] == "*Person*\n(Leader)"


def test_as_node_omits_designation_suffix_when_absent(make_person):
    person = make_person(name="Person")
    bookmark = Bookmark.objects.create(person=person)

    node = bookmark.as_node()

    assert node["label"] == "*Person*"


def test_as_node_custom_label_overrides_generated_label(make_person):
    person = make_person(name="Person", designation="Leader")
    bookmark = Bookmark.objects.create(person=person, label="Custom Label")

    node = bookmark.as_node()

    assert node["label"] == "Custom Label"


def test_as_node_applies_color_when_set(make_person):
    person = make_person(name="Person")
    bookmark = Bookmark.objects.create(person=person, color="ff0000")

    node = bookmark.as_node()

    assert node["color"] == "ff0000"


def test_as_node_ignores_blank_color(make_person):
    person = make_person(name="Person")
    bookmark = Bookmark.objects.create(person=person, color="")

    node = bookmark.as_node()

    assert "color" not in node


def test_as_node_builds_font_dict_from_size_and_color(make_person):
    person = make_person(name="Person")
    bookmark = Bookmark.objects.create(person=person, font_size=20, font_color="00ff00")

    node = bookmark.as_node()

    assert node["font"] == {"multi": "markdown", "size": 20, "color": "00ff00"}


def test_as_node_font_dict_omits_unset_size_and_color(make_person):
    person = make_person(name="Person")
    bookmark = Bookmark.objects.create(person=person)

    node = bookmark.as_node()

    assert node["font"] == {"multi": "markdown"}


def test_str_returns_person_str(make_person):
    person = make_person(name="Person")
    bookmark = Bookmark.objects.create(person=person)

    assert str(bookmark) == str(person)
