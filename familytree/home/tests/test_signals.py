from home.models import Bookmark


def test_always_generate_home_tree_runs_on_bookmark_save(make_person, monkeypatch):
    person = make_person(name="Person", access="public")
    calls = []
    monkeypatch.setattr("home.signals.generate_home_tree", lambda: calls.append("save"))

    Bookmark.objects.create(person=person)

    assert calls == ["save"]


def test_always_generate_home_tree_runs_on_bookmark_delete(make_person, monkeypatch):
    person = make_person(name="Person", access="public")
    bookmark = Bookmark.objects.create(person=person)
    calls = []
    monkeypatch.setattr("home.signals.generate_home_tree", lambda: calls.append("delete"))

    bookmark.delete()

    assert calls == ["delete"]


def test_generate_if_bookmarked_runs_on_every_person_save(make_person, monkeypatch):
    """hasattr(Person, "bookmark") checks the class-level reverse OneToOne
    descriptor (always present once the home app is loaded), not whether this
    particular person has a bookmark - so the tree is regenerated unconditionally."""
    calls = []
    monkeypatch.setattr("home.signals.generate_home_tree", lambda: calls.append(True))

    make_person(name="NotBookmarked")

    assert calls == [True]
