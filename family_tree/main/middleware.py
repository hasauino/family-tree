from django.conf import settings
from main.session_configs import configs


def force_language_cookie(get_response):

    def middleware(request):
        if request.COOKIES.get(settings.LANGUAGE_COOKIE_NAME, None) is None:
            request.COOKIES[
                settings.LANGUAGE_COOKIE_NAME] = settings.LANGUAGE_CODE
        response = get_response(request)
        response.set_cookie(settings.LANGUAGE_COOKIE_NAME,
                            request.COOKIES[settings.LANGUAGE_COOKIE_NAME])
        return response

    return middleware


def populate_session_defaults(get_response):

    def middleware(request):
        for config in configs.values():
            request.session.setdefault(config.key, config.default)
        return get_response(request)

    return middleware