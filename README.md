# Family Tree



This is a platfrom for storing, browsing, and updating a family tree, made using [Django](https://www.djangoproject.com/).

[Demo](http://omaritree.com/)



It has the following features:

- [x] Users can add new people, navigate the tree (interactively), and search from a root to any person at once.
- [x] Supported languages: English, and Arabic. (configurable only during deployment).
- [x] Backups every day at 3:00 am. With a restore DB page accessible to staff users.
- [x] User registration through email.
- [x] Staff users see notification on new additions (newly added persons).
- [x] Normal users can add new persons to the tree, but these additions are **local** and only visible to the user. Once they are published by a staff member, these additions will become **global**.
- [x] Help and about page are editable using [Wagtail](https://wagtail.org/) CMS.
- [x] Staff users can add shortcuts (bookmarks), which can be further customized (color, font color, size, and overwrite label).



## Getting Started

For admins, once the app is running:

- Default user name: admin
- default password: admin

- Admin page: `/edarah`
- [Wagtail](https://wagtail.org/) editor (for editing home, and about pages): `/tahreer`

- There is a normal user whose credentials are:
  - Username: user1
  - Password: user12345678

### Docker (production)

1. Install [docker compose](https://docs.docker.com/compose/install/).
2. Adjust the configuration in the [.env](.env) file (domains, secrets, email, etc.).
3. :rocket: start everything (backend + nginx + Flutter web app):

```bash
docker compose up
```

The backend is served on `PORT` (behind nginx) and the Flutter web app on `WEB_PORT`, as configured in `.env`.

### Docker (local)

To run the same docker setup locally (e.g. `localhost` URLs instead of the real domains), use `.env.local` instead:

```bash
docker compose --env-file .env.local up
```

Go to [localhost:9000](http://localhost:9000/) for the backend and [localhost:9002](http://localhost:9002/) for the Flutter web app (or whichever `PORT`/`WEB_PORT` you set in `.env.local`).

### Running directly (without Docker)

Backend (Django):

```bash
hatch run migrate
hatch run server
```

Go to [localhost:8000](http://localhost:8000/).

Mobile/web app (Flutter), from the `mobile/` directory:

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

See [mobile/README.md](mobile/README.md) for platform-specific `API_BASE_URL` values (Android emulator, physical device, etc.).

## Development

### Setup

- During development, you can change configurations from the [`.env`](.env) file. You can tell git to ignore your changes:

```
git update-index --assume-unchanged .env
```

- This project uses [ruff](https://docs.astral.sh/ruff/) for formatting and linting, enforced on commit via [pre-commit](https://pre-commit.com/) hooks. Install them once after cloning:

```bash
hatch run install-hooks
```

From then on, `git commit` will automatically format and fix your staged Python files (re-staging the result). You can also run the checks manually:

```bash
hatch run style  # check only
hatch run fix    # check and auto-fix
```

- The [`.env`](.env) file is loaded automatically (via [python-dotenv](https://pypi.org/project/python-dotenv/)) whenever Django starts, so the environment variables defined there are picked up no matter how you run the project. This way you can select a different database file, a different language, or different project settings, etc.

- For example, you can run the Django development server as follows:

```bash
hatch run server
```

- You can also open a Django shell (using [IPython](https://ipython.org/)):

```bash
hatch run shell
```

- Other common Django operations are also available as hatch scripts:

```bash
hatch run migrate
hatch run makemigrations
hatch run createsuperuser
hatch run collectstatic
```

### Testing

The test suite is written with [pytest](https://docs.pytest.org/) (via [pytest-django](https://pytest-django.readthedocs.io/)). Run it with:

```bash
hatch run test
```

This runs with coverage by default (via [pytest-cov](https://pytest-cov.readthedocs.io/)), printing a per-file report with the lines that are still missing coverage. You can pass any pytest arguments through, e.g. to run a specific file or skip coverage:

```bash
hatch run test familytree/main/tests/test_models.py
hatch run test --no-cov
```

### Localization

```bash
hatch run makemessages
```

then compile:

```bash
hatch run compilemessages
```

