import logging
import re

from django.utils import translation
from main.models import Person
from main.utils import get_domain

language_pattern = re.compile(r"(\w+)(-\w+)?")


def get_language_code(request):
    current_language = translation.get_language_from_request(request,
                                                             check_path=True)
    try:
        return re.findall(language_pattern, current_language)[0][0]
    except Exception as e:
        logging.error(f"Could not get language code. Got this error {e}. "
                      "Will resolve to default")
        return current_language


def main(request):
    text_direction = "rtl" if translation.get_language_bidi() else "ltr"
    notifications = []
    if request.user.is_staff:
        notifications = Person.objects.filter(access='private').count()
    return {
        "text_direction": text_direction,
        "notifications": notifications,
        "language_code": get_language_code(request),
        "current_domain": get_domain(request),
    }
