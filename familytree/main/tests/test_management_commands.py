from io import StringIO

import pytest

from main.management.commands.create_db_backup import Command, list_backups


@pytest.fixture
def backup_env(tmp_path, settings, monkeypatch):
    db_path = tmp_path / "db.sqlite3"
    db_path.write_text("dummy db content")

    monkeypatch.setitem(settings.DATABASES["default"], "NAME", db_path)
    settings.DB_BACKUP_DIR = tmp_path / "backups"
    settings.NUMBER_OF_BACKUPS = 30

    return db_path, tmp_path / "backups"


# ---------------------------------------------------------------------------
# list_backups
# ---------------------------------------------------------------------------


def test_list_backups_returns_sqlite_files_sorted_newest_first(backup_env):
    _, backup_dir = backup_env
    backup_dir.mkdir()
    older = backup_dir / "db-20230101000000.sqlite3"
    newer = backup_dir / "db-20240101000000.sqlite3"
    older.write_text("a")
    newer.write_text("b")
    (backup_dir / "ignored.txt").write_text("c")

    assert list_backups() == [newer, older]


def test_list_backups_empty_when_dir_has_no_backups(backup_env):
    _, backup_dir = backup_env
    backup_dir.mkdir()

    assert list_backups() == []


# ---------------------------------------------------------------------------
# Command.handle
# ---------------------------------------------------------------------------


def test_handle_creates_a_timestamped_backup_copy(backup_env):
    db_path, backup_dir = backup_env

    Command().handle()

    backups = list(backup_dir.glob("*.sqlite3"))
    assert len(backups) == 1
    assert backups[0].name.startswith("db-")
    assert backups[0].read_text() == db_path.read_text()


def test_handle_removes_oldest_backup_when_over_limit(backup_env, settings):
    _, backup_dir = backup_env
    backup_dir.mkdir()
    settings.NUMBER_OF_BACKUPS = 1
    oldest = backup_dir / "db-20200101000000.sqlite3"
    newer_existing = backup_dir / "db-20210101000000.sqlite3"
    oldest.write_text("old")
    newer_existing.write_text("newer")

    Command().handle()

    remaining = {p.name for p in backup_dir.glob("*.sqlite3")}
    assert oldest.name not in remaining
    assert newer_existing.name in remaining
    assert len(remaining) == 2  # newer_existing + freshly created backup


def test_handle_keeps_all_backups_when_under_limit(backup_env, settings):
    _, backup_dir = backup_env
    backup_dir.mkdir()
    settings.NUMBER_OF_BACKUPS = 30
    existing = backup_dir / "db-20200101000000.sqlite3"
    existing.write_text("old")

    Command().handle()

    remaining = {p.name for p in backup_dir.glob("*.sqlite3")}
    assert existing.name in remaining
    assert len(remaining) == 2


def test_handle_reports_error_to_stderr_on_failure(backup_env, monkeypatch):
    def raise_error(cmd, shell=False):
        raise OSError("boom")

    monkeypatch.setattr("main.management.commands.create_db_backup.subprocess.call", raise_error)
    err = StringIO()

    Command(stderr=err).handle()

    assert "Backup failed" in err.getvalue()
    assert "boom" in err.getvalue()
