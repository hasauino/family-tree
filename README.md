# Family Tree



This is a server for storing, browsing, and updating a family tree.



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

