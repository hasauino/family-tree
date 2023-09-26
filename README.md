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



## Dev

### Localization

```bash
./manage.py makemessages -i venv -a
```

then compile:

```bash
./manage.py compilemessages -i venv
```

