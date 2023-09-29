FROM python:3.11
RUN apt update
RUN apt -y install cron
COPY pyproject.toml ./pyproject.toml
RUN touch README.md
RUN mkdir familytree 
RUN touch familytree/__init__.py
RUN pip install .
RUN rm -rf familytree/
RUN rm README.md
RUN rm pyproject.toml
COPY familytree/project/db_backup_cron /etc/cron.d/db_backup_cron
RUN chmod +x /etc/cron.d/db_backup_cron
RUN crontab /etc/cron.d/db_backup_cron