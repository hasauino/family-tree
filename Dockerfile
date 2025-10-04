FROM python:3.11
RUN apt update
RUN apt -y install cron
COPY pyproject.toml ./pyproject.toml
RUN touch README.md
RUN mkdir family_tree 
RUN touch family_tree/__init__.py
RUN pip install .
RUN rm -rf family_tree/
RUN rm README.md
RUN rm pyproject.toml
COPY src/family_tree/project/db_backup_cron /etc/cron.d/db_backup_cron
RUN chmod +x /etc/cron.d/db_backup_cron
RUN crontab /etc/cron.d/db_backup_cron