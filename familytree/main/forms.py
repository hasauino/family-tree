from django_registration.forms import RegistrationForm
from django_registration.forms import RegistrationFormUniqueEmail
from django_registration.forms import RegistrationFormTermsOfService
from django.forms import ModelForm, NumberInput
from main.models import User
from django import forms


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


class SettingsForm(ModelForm):

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
