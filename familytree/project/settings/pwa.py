from .base import *  # noqa: F403

PWA_APP_NAME = SITE_NAME
PWA_APP_DESCRIPTION = "A web app for navigating a family tree"
PWA_APP_THEME_COLOR = '#343a40'
PWA_APP_BACKGROUND_COLOR = '#f6f6f6'
PWA_APP_DISPLAY = 'standalone'
PWA_APP_SCOPE = '/'
PWA_APP_ORIENTATION = 'any'
PWA_APP_START_URL = '/'
PWA_APP_STATUS_BAR_COLOR = 'default'
PWA_APP_ICONS = [{'src': '/static/favicon.png', 'sizes': '512x512'}]
PWA_APP_ICONS_APPLE = PWA_APP_ICONS
PWA_APP_SPLASH_SCREEN = [{
    'src':
    '/static/splash_screen_640.png',
    'media':
    '(device-width: 320px) and (device-height: 568px) and (-webkit-device-pixel-ratio: 2)'
}]
PWA_APP_DIR = "ltr"  # "rtl" if translation.get_language_bidi() else "ltr"
PWA_APP_LANG = LANGUAGE_CODE
PWA_APP_SHORTCUTS = [{
    'name': 'from-to',
    'url': '/navigation',
    'description': 'Show tree from ancestor to child'
}]
PWA_APP_SCREENSHOTS = [{
    'src': '/static/splash_screen_640.png',
    'sizes': '640x1136',
    "type": "image/png"
}]
