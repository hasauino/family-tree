from django import template
from django.conf import settings

register = template.Library()


@register.simple_tag
def read_settings(key):
    return getattr(settings, key, None)
