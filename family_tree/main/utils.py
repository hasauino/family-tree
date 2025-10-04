import logging
import os
import re

from django.conf import settings

address_pattern = re.compile(r"([\w\-_\.]+):?(\d+)?")
current_domain = None


def get_host_port(url):
    return address_pattern.findall(url)[0]


def get_domain(request):
    global current_domain

    if current_domain is not None:
        return current_domain

    if settings.IS_PRODUCTION:
        current_domain = request.get_host()
        return current_domain

    try:
        host, _ = get_host_port(request.get_host())
        port = os.environ["PORT"]
        current_domain = f"{host}:{port}"
    except Exception as e:
        logging.error(f"Could not get correct domain. Got this error {e}. "
                      "Will resolve to default")
        current_domain = request.get_host()

    return current_domain
