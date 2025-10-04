from django.contrib import admin

# Register your models here.
from .models import Person, User
from django.contrib.auth.admin import UserAdmin


class UserAdmin(UserAdmin):
    ordering = ('-date_joined', )
    fieldsets = UserAdmin.fieldsets
    fieldsets[1][1]['fields'] += ('father_name', 'grandfather_name',
                                  'birth_date', 'birth_place')

    list_display = (
        'username',
        'date_joined',
        'first_name',
        'father_name',
        'grandfather_name',
        'last_name',
        'email',
    )


admin.site.register(Person)
admin.site.register(User, UserAdmin)
