from django.http import HttpResponse

from main.middleware import force_language_cookie, populate_session_defaults


def respond(request):
    return HttpResponse()


# ---------------------------------------------------------------------------
# force_language_cookie
# ---------------------------------------------------------------------------


def test_force_language_cookie_sets_default_when_missing(rf, settings):
    settings.LANGUAGE_COOKIE_NAME = "language"
    settings.LANGUAGE_CODE = "en"
    request = rf.get("/")

    response = force_language_cookie(respond)(request)

    assert request.COOKIES["language"] == "en"
    assert response.cookies["language"].value == "en"


def test_force_language_cookie_preserves_existing_cookie(rf, settings):
    settings.LANGUAGE_COOKIE_NAME = "language"
    settings.LANGUAGE_CODE = "en"
    request = rf.get("/")
    request.COOKIES["language"] = "ar"

    response = force_language_cookie(respond)(request)

    assert request.COOKIES["language"] == "ar"
    assert response.cookies["language"].value == "ar"


# ---------------------------------------------------------------------------
# populate_session_defaults
# ---------------------------------------------------------------------------


def test_populate_session_defaults_sets_defaults(rf):
    request = rf.get("/")
    request.session = {}

    populate_session_defaults(respond)(request)

    assert request.session["tools_display"] == "none"
    assert request.session["theme"] == "default"


def test_populate_session_defaults_does_not_overwrite_existing_values(rf):
    request = rf.get("/")
    request.session = {"theme": "dark"}

    populate_session_defaults(respond)(request)

    assert request.session["theme"] == "dark"
    assert request.session["tools_display"] == "none"
