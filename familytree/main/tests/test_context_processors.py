from django.utils import translation

import main.context_processors as context_processors_module
from main.context_processors import get_language_code
from main.context_processors import main as main_context_processor


# ---------------------------------------------------------------------------
# get_language_code
# ---------------------------------------------------------------------------


def test_get_language_code_extracts_primary_subtag(rf, monkeypatch):
    monkeypatch.setattr(
        context_processors_module.translation,
        "get_language_from_request",
        lambda request, check_path=False: "en-us",
    )
    assert get_language_code(rf.get("/")) == "en"


def test_get_language_code_handles_language_without_region(rf, monkeypatch):
    monkeypatch.setattr(
        context_processors_module.translation,
        "get_language_from_request",
        lambda request, check_path=False: "ar",
    )
    assert get_language_code(rf.get("/")) == "ar"


def test_get_language_code_falls_back_to_raw_value_on_error(rf, monkeypatch):
    monkeypatch.setattr(
        context_processors_module.translation,
        "get_language_from_request",
        lambda request, check_path=False: None,
    )
    assert get_language_code(rf.get("/")) is None


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------


def test_main_context_processor_counts_private_persons_for_staff(rf, staff_user, make_person):
    make_person(name="Public", access="public")
    make_person(name="Private1", access="private")
    make_person(name="Private2", access="private")
    request = rf.get("/")
    request.user = staff_user

    context = main_context_processor(request)

    assert context["notifications"] == 2


def test_main_context_processor_has_no_notifications_for_non_staff(rf, normal_user, make_person):
    make_person(name="Private", access="private")
    request = rf.get("/")
    request.user = normal_user

    context = main_context_processor(request)

    assert context["notifications"] == []


def test_main_context_processor_text_direction_for_rtl_language(rf, normal_user):
    request = rf.get("/")
    request.user = normal_user
    with translation.override("ar"):
        context = main_context_processor(request)
    assert context["text_direction"] == "rtl"


def test_main_context_processor_text_direction_for_ltr_language(rf, normal_user):
    request = rf.get("/")
    request.user = normal_user
    with translation.override("en"):
        context = main_context_processor(request)
    assert context["text_direction"] == "ltr"


def test_main_context_processor_includes_language_code_and_domain(rf, normal_user):
    request = rf.get("/", HTTP_HOST="example.com")
    request.user = normal_user

    context = main_context_processor(request)

    assert "language_code" in context
    assert "current_domain" in context
