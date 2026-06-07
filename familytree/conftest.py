import pytest

from main.models import Person, User


@pytest.fixture
def staff_user(db):
    return User.objects.create_user(username="staff", email="staff@example.com", password="pw", is_staff=True)


@pytest.fixture
def normal_user(db):
    return User.objects.create_user(username="normal", email="normal@example.com", password="pw")


@pytest.fixture
def other_user(db):
    return User.objects.create_user(username="other", email="other@example.com", password="pw")


@pytest.fixture
def make_person(db):
    def _make_person(name="Person", parent=None, access="public", editors=None, **extra_fields):
        person = Person(name=name, parent=parent, access=access, **extra_fields)
        person.save()
        if editors:
            person.editors.add(*editors)
        return person

    return _make_person
