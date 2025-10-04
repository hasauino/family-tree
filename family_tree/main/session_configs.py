class SessionConfig:

    def __init__(self, key, default, choices) -> None:
        self.key = key
        self.default = default
        self.choices = choices

    def validate(self, value):
        if value in self.choices:
            return True
        return False


tools_display = SessionConfig("tools_display", "none", ["none", "inline"])
theme = SessionConfig("theme", "default", ["dark", "light"])

configs = {config.key: config for config in [tools_display, theme]}
