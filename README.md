# Family Tree



This is a server for storing, browsing, and updating a family tree, made using [Django](https://www.djangoproject.com/).

[Demo](http://new.omaritree.com/)



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

1- Install [docker compose](https://docs.docker.com/compose/install/).

2- Adjust the configurations in the [.env](.env) file.

3 :rocket:  start the server:

```bash
docker compose up
```

Go to [localhost:8000](http://localhost:8000/) (or the port you configured). For admins:

- Default user name: admin
- default password: admin

- Admin page: http://localhost:8000/edarah
- [Wagtail](https://wagtail.org/) editor (for editing home, and about pages): http://localhost:8000/tahreer

- There is a normal user whose creditials are:
  - Username: user1
  - Password: user12345678

## Development

### Setup

- During development, you can change configurations from the [`.env`](.env) file. You can tell git to ignore your changes:

```
git update-index --assume-unchanged .env
```

- To source this file automatically when you run Django commands through poetry,  you can add [poetry-dotenv-plugin](https://pypi.org/project/poetry-dotenv-plugin/) to poetry.



- For example, you can run Django development server as follows:

```bash
poetry run familytree/manage.py runserver
```

this will use the environment variables define in `.env`. This way you can selected a different Database file, a different language ,or different project settings, etc..

### Localization

```bash
poetry run familytree/manage.py makemessages -a
```

then compile:

```bash
poetry run familytree/manage.py compilemessages
```

