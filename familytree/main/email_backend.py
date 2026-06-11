"""Django email backend that sends through Resend's HTTP API.

Keeps the ordinary Django mail interface (``send_mail``, ``EmailMessage``,
``user.email_user``) working, so the registration / activation flow needs no
changes — messages just go out via Resend instead of SMTP.
"""

import resend
from django.conf import settings
from django.core.mail.backends.base import BaseEmailBackend


class ResendEmailBackend(BaseEmailBackend):
    def __init__(self, fail_silently=False, **kwargs):
        super().__init__(fail_silently=fail_silently, **kwargs)
        self.api_key = getattr(settings, "RESEND_API_KEY", "") or ""

    def send_messages(self, email_messages):
        if not email_messages:
            return 0
        if not self.api_key:
            if not self.fail_silently:
                raise ValueError("RESEND_API_KEY is not configured")
            return 0
        resend.api_key = self.api_key
        sent = 0
        for message in email_messages:
            try:
                resend.Emails.send(self._params(message))
                sent += 1
            except Exception:
                if not self.fail_silently:
                    raise
        return sent

    @staticmethod
    def _params(message):
        params = {
            "from": message.from_email,
            "to": list(message.to),
            "subject": message.subject,
        }
        # A plain EmailMessage carries its body as text or html depending on
        # content_subtype; EmailMultiAlternatives adds an html alternative.
        if message.content_subtype == "html":
            params["html"] = message.body
        else:
            params["text"] = message.body
        for content, mimetype in getattr(message, "alternatives", None) or []:
            if mimetype == "text/html":
                params["html"] = content
        if message.cc:
            params["cc"] = list(message.cc)
        if message.bcc:
            params["bcc"] = list(message.bcc)
        if message.reply_to:
            params["reply_to"] = list(message.reply_to)
        return params
