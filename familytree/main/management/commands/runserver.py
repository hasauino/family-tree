import os
from django.core.management.commands.runserver import Command as BaseCommand
from main.utils import get_host_port
import logging


class Command(BaseCommand):
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
