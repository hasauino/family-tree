import pathlib
import subprocess
from datetime import datetime

from django.conf import settings
from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = "Creates a timestamped copy of the sqlite3 DB file"

    def handle(self, *args, **options):
        db_path_rel = pathlib.Path(settings.DATABASES['default']['NAME'])
        root_dir = pathlib.Path(settings.BASE_DIR).parent
        db_path = root_dir / db_path_rel
        db_name = db_path.name[:-8]  # remove .sqlite3
        date = datetime.now()
        year = str("{:02d}".format(date.date().year))
        month = str("{:02d}".format(date.date().month))
        day = str("{:02d}".format(date.date().day))
        hour = str("{:02d}".format(date.time().hour))
        minute = str("{:02d}".format(date.time().minute))
        second = str("{:02d}".format(date.time().second))
        backed_db_name = f"{db_name}-{year}{month}{day}{hour}{minute}{second}.sqlite3"
        subprocess.call(f"mkdir -p {settings.DB_BACKUP_DIR}", shell=True)
        subprocess.call(
            f"cp {db_path} {settings.DB_BACKUP_DIR}/{backed_db_name}",
            shell=True)
