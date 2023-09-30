from django import forms
from django.utils.translation import gettext_lazy as _
from django_registration.forms import (RegistrationFormTermsOfService,
                                       RegistrationFormUniqueEmail)
from main.models import Person, User


class UserForm(RegistrationFormUniqueEmail, RegistrationFormTermsOfService):

    class Meta(RegistrationFormUniqueEmail.Meta):
        model = User
        fields = [
            'username', 'email', 'first_name', 'last_name', 'birth_date',
            'father_name', 'grandfather_name', 'birth_place'
        ]
        widgets = {
            'birth_date': forms.TextInput(attrs={'autocomplete': 'off'})
        }


class SettingsForm(forms.ModelForm):

    class Meta:
        model = User
        fields = [
            'first_name',
            'father_name',
            'grandfather_name',
            'last_name',
            'birth_date',
            'birth_place',
        ]


class PersonForm(forms.ModelForm):

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["designation"].widget.attrs.update({"rows": "3"})
        self.fields["history"].widget.attrs.update({"rows": "3"})
        self.fields["reference"].widget.attrs.update({"rows": "3"})

    children = forms.CharField(label=_("Children"), max_length=1000)

    class Meta:
        model = Person
        fields = [
            'name',
            'designation',
            'history',
            'reference',
        ]
