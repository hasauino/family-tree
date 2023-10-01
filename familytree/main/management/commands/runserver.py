import os

from main.utils import get_host_port

# import runserver from staticfiles app (since it overrides django runserver)
# https://stackoverflow.com/a/34993964/14447629
from django.contrib.staticfiles.management.commands import runserver


class Command(runserver.Command):
    """
    Extending runserver command to update PORT env variable.
    The PORT env variable is used though out all setups:
    - Inside docker dev settings
    - Inside docker production settings
    - and here, when using runserver command
    In the latter case, PORT env var won't be used, 
    hence this class is used to do that
    """

    def execute(self, *args, **options):
        if options["addrport"] is None:
            os.environ["PORT"] = "8000"
        else:
            _, port = get_host_port(options["addrport"])
            os.environ["PORT"] = port
        super().execute(*args, **options)
