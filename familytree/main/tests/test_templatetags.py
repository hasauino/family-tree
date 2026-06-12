from main.templatetags.read_settings import read_settings


def test_read_settings_returns_existing_setting(settings):
    settings.SITE_NAME = "Test Site"
    assert read_settings("SITE_NAME") == "Test Site"


def test_read_settings_returns_none_for_missing_setting():
    assert read_settings("THIS_SETTING_DOES_NOT_EXIST") is None
