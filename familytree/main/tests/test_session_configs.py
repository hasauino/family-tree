from main.session_configs import SessionConfig, configs, theme, tools_display


def test_validate_returns_true_for_known_choice():
    config = SessionConfig("key", "default", ["a", "b"])
    assert config.validate("a") is True


def test_validate_returns_false_for_unknown_choice():
    config = SessionConfig("key", "default", ["a", "b"])
    assert config.validate("c") is False


def test_tools_display_config():
    assert tools_display.key == "tools_display"
    assert tools_display.default == "none"
    assert tools_display.validate("inline") is True
    assert tools_display.validate("invalid") is False


def test_theme_config():
    assert theme.key == "theme"
    assert theme.default == "default"
    assert theme.validate("dark") is True
    assert theme.validate("light") is True
    assert theme.validate("invalid") is False


def test_configs_dict_indexes_by_key():
    assert configs["tools_display"] is tools_display
    assert configs["theme"] is theme
