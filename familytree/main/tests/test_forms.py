import pytest

from main.forms import PersonForm, SettingsForm, UserForm

VALID_PASSWORD = "Xk7$pLm92qRt!"


def valid_user_form_data(**overrides):
    data = {
        "username": "newuser",
        "email": "newuser@example.com",
        "first_name": "New",
        "last_name": "User",
        "birth_date": "1990-01-01",
        "father_name": "Father",
        "grandfather_name": "Grandfather",
        "birth_place": "City",
        "password1": VALID_PASSWORD,
        "password2": VALID_PASSWORD,
        "tos": True,
    }
    data.update(overrides)
    return data


# ---------------------------------------------------------------------------
# UserForm
# ---------------------------------------------------------------------------


def test_user_form_valid_with_complete_data(db):
    form = UserForm(data=valid_user_form_data())
    assert form.is_valid(), form.errors


def test_user_form_creates_user_on_save(db):
    form = UserForm(data=valid_user_form_data())
    assert form.is_valid(), form.errors
    user = form.save()
    assert user.pk is not None
    assert user.username == "newuser"
    assert user.check_password(VALID_PASSWORD)


def test_user_form_requires_terms_of_service_agreement(db):
    form = UserForm(data=valid_user_form_data(tos=False))
    assert not form.is_valid()
    assert "tos" in form.errors


def test_user_form_rejects_mismatched_passwords(db):
    form = UserForm(data=valid_user_form_data(password2="SomethingDifferent99!"))
    assert not form.is_valid()
    assert "password2" in form.errors


def test_user_form_rejects_duplicate_email(db, normal_user):
    form = UserForm(data=valid_user_form_data(email=normal_user.email, username="anotherusername"))
    assert not form.is_valid()
    assert "email" in form.errors


# ---------------------------------------------------------------------------
# SettingsForm
# ---------------------------------------------------------------------------


def test_settings_form_valid_with_complete_data(db):
    form = SettingsForm(
        data={
            "first_name": "Jane",
            "father_name": "John",
            "grandfather_name": "Jack",
            "last_name": "Doe",
            "birth_date": "1985-05-05",
            "birth_place": "Somewhere",
        }
    )
    assert form.is_valid(), form.errors


def test_settings_form_updates_existing_user(normal_user):
    form = SettingsForm(
        data={
            "first_name": "Jane",
            "father_name": "John",
            "grandfather_name": "Jack",
            "last_name": "Doe",
            "birth_date": "1985-05-05",
            "birth_place": "Somewhere",
        },
        instance=normal_user,
    )
    assert form.is_valid(), form.errors
    user = form.save()
    assert user.pk == normal_user.pk
    assert user.first_name == "Jane"


# ---------------------------------------------------------------------------
# PersonForm
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("field_name", ["designation", "history", "reference"])
def test_person_form_sets_textarea_rows(field_name):
    form = PersonForm()
    assert form.fields[field_name].widget.attrs["rows"] == "3"


def test_person_form_valid_with_only_name():
    form = PersonForm(data={"name": "Alice", "designation": "", "history": "", "reference": "", "children": ""})
    assert form.is_valid(), form.errors


def test_person_form_requires_name():
    form = PersonForm(data={"name": "", "designation": "", "history": "", "reference": "", "children": ""})
    assert not form.is_valid()
    assert "name" in form.errors


def test_person_form_children_field_is_optional():
    form = PersonForm(data={"name": "Alice", "designation": "", "history": "", "reference": ""})
    assert form.is_valid(), form.errors
    assert form.cleaned_data["children"] == ""
