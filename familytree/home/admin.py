from django.contrib import admin
from django.shortcuts import redirect

# Register your models here.
from .models import Bookmark, HomeSettings

admin.site.register(Bookmark)


@admin.register(HomeSettings)
class HomeSettingsAdmin(admin.ModelAdmin):
    """Singleton admin: only one HomeSettings row (pk=1) ever exists."""

    def has_add_permission(self, request):
        return not HomeSettings.objects.exists()

    def has_delete_permission(self, request, obj=None):
        return False

    def changelist_view(self, request, extra_context=None):
        # Skip the changelist and go straight to the singleton's edit page.
        obj = HomeSettings.load()
        return redirect("admin:home_homesettings_change", obj.pk)
