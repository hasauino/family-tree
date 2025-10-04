import pathlib
import subprocess
from datetime import datetime

from django.conf import settings
from django.core.management.base import BaseCommand


def list_backups():
    return list(sorted(settings.DB_BACKUP_DIR.glob("*.sqlite3"), reverse=True))


class Command(BaseCommand):
    help = "Creates a timestamped copy of the sqlite3 DB file"

    def handle(self, *args, **options):
        try:
            db_path = settings.DATABASES['default']['NAME']
            self.stdout.write(str(db_path))
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

            # Delete oldest backup if number of backups > limit
            backups = list_backups()
            if len(backups) > settings.NUMBER_OF_BACKUPS:
                oldest_backup_name = backups[-1].name
                subprocess.call(
                    f"rm {settings.DB_BACKUP_DIR}/{oldest_backup_name}",
                    shell=True)
        except Exception as error:
            self.stderr.write(f"Backup failed with the following error:\n{error}")
