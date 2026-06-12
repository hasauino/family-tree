import pytest

from main.forms import PersonForm, SettingsForm

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
