import pytest

import main.utils as utils_module
from main.utils import get_domain, get_host_port


@pytest.fixture(autouse=True)
def reset_current_domain(monkeypatch):
    monkeypatch.setattr(utils_module, "current_domain", None)


@pytest.mark.parametrize(
    "url, expected",
    [
        ("localhost:8000", ("localhost", "8000")),
        ("example.com", ("example.com", "")),
        ("192.168.1.1:9999", ("192.168.1.1", "9999")),
    ],
)
def test_get_host_port(url, expected):
    assert get_host_port(url) == expected


def test_get_domain_in_production_uses_request_host(rf, settings):
    settings.IS_PRODUCTION = True
    request = rf.get("/", HTTP_HOST="prod.example.com")
    assert get_domain(request) == "prod.example.com"


def test_get_domain_caches_value_after_first_call(rf, settings):
    settings.IS_PRODUCTION = True
    request = rf.get("/", HTTP_HOST="first.example.com")
    assert get_domain(request) == "first.example.com"

    other_request = rf.get("/", HTTP_HOST="second.example.com")
    assert get_domain(other_request) == "first.example.com"


def test_get_domain_in_dev_appends_port_from_environment(rf, settings, monkeypatch):
    settings.IS_PRODUCTION = False
    monkeypatch.setenv("PORT", "1234")
    request = rf.get("/", HTTP_HOST="localhost:8000")
    assert get_domain(request) == "localhost:1234"


def test_get_domain_in_dev_falls_back_to_request_host_without_port_env(rf, settings, monkeypatch):
    settings.IS_PRODUCTION = False
    monkeypatch.delenv("PORT", raising=False)
    request = rf.get("/", HTTP_HOST="localhost:8000")
    assert get_domain(request) == "localhost:8000"
