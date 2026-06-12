"""Firebase Cloud Messaging (FCM) push delivery.

This module is intentionally *best-effort*: if Firebase isn't configured (no
credentials, or the ``firebase-admin`` package isn't installed) every call
becomes a no-op so the app — and the test suite — runs fine without push. Push
is delivered to every :class:`~main.models.DeviceToken` registered for a user;
stale tokens that FCM reports as unregistered are pruned automatically.

Configuration (see ``project/settings/base.py``):

* ``FIREBASE_CREDENTIALS_FILE`` – path to the service-account JSON downloaded
  from the Firebase console (Project settings → Service accounts). Leave unset
  to disable push entirely.

Android push is free via FCM. iOS push additionally requires an APNs auth key
uploaded to the same Firebase project (needs a paid Apple Developer account).
"""

import logging

from django.conf import settings

logger = logging.getLogger(__name__)

# Lazily-initialised firebase_admin app; None until first successful init,
# False once we've determined push is unavailable (so we only warn once).
_app = None


def _get_app():
    """Return an initialised firebase_admin app, or None if push is disabled."""
    global _app
    if _app is not None:
        return _app or None

    cred_file = getattr(settings, "FIREBASE_CREDENTIALS_FILE", None)
    if not cred_file:
        _app = False
        return None
    try:
        import firebase_admin
        from firebase_admin import credentials

        if firebase_admin._apps:  # already initialised elsewhere
            _app = firebase_admin.get_app()
        else:
            _app = firebase_admin.initialize_app(credentials.Certificate(cred_file))
        return _app
    except Exception:  # pragma: no cover - depends on optional dep / file
        logger.warning("Firebase push disabled: could not initialise firebase_admin", exc_info=True)
        _app = False
        return None


def send_to_user(user, *, title, body, data=None):
    """Deliver a push notification to all of ``user``'s registered devices.

    No-op (returns 0) when push is unconfigured. Returns the number of devices
    the message was accepted for. Prunes tokens FCM reports as unregistered.
    """
    app = _get_app()
    if app is None:
        return 0

    from firebase_admin import messaging

    from main.models import DeviceToken

    tokens = list(user.device_tokens.values_list("token", flat=True))
    if not tokens:
        return 0

    # FCM data payload must be all-string.
    str_data = {str(k): str(v) for k, v in (data or {}).items()}
    message = messaging.MulticastMessage(
        tokens=tokens,
        notification=messaging.Notification(title=title, body=body),
        data=str_data,
        android=messaging.AndroidConfig(priority="high"),
        apns=messaging.APNSConfig(payload=messaging.APNSPayload(aps=messaging.Aps(sound="default"))),
    )
    try:
        response = messaging.send_each_for_multicast(message, app=app)
    except Exception:  # pragma: no cover - network/credentials
        logger.warning("FCM send failed", exc_info=True)
        return 0

    stale = []
    for token, result in zip(tokens, response.responses):
        if not result.success:
            err = getattr(result.exception, "code", "")
            if err in ("registration-token-not-registered", "invalid-argument"):
                stale.append(token)
    if stale:
        DeviceToken.objects.filter(token__in=stale).delete()
    return response.success_count
