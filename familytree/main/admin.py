from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

# Register your models here.
from .models import DeviceToken, Notification, Person, User


class UserAdmin(UserAdmin):
    ordering = ("-date_joined",)
    fieldsets = UserAdmin.fieldsets
    fieldsets[1][1]["fields"] += ("father_name", "grandfather_name", "birth_date", "birth_place")

    list_display = (
        "username",
        "date_joined",
        "first_name",
        "father_name",
        "grandfather_name",
        "last_name",
        "email",
    )


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ("recipient", "kind", "count", "is_read", "updated_at")
    list_filter = ("kind", "read_at")
    search_fields = ("recipient__username", "title", "body")
    raw_id_fields = ("recipient", "actor", "person")


@admin.register(DeviceToken)
class DeviceTokenAdmin(admin.ModelAdmin):
    list_display = ("user", "platform", "last_seen")
    list_filter = ("platform",)
    search_fields = ("user__username", "token")
    raw_id_fields = ("user",)


admin.site.register(Person)
admin.site.register(User, UserAdmin)
