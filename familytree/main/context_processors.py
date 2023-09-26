import re
from django.utils import translation

language_pattern = re.compile(r"(\w+)(-\w+)?")


def main(request):
    current_language = translation.get_language_from_request(request,
                                                             check_path=True)
    text_direction = "rtl" if translation.get_language_bidi() else "ltr"
    return {
        "text_direction": text_direction,
        "language_code": re.findall(language_pattern, current_language)[0][0]
    }
