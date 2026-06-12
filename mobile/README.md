# Family Tree — Flutter mobile app

A Flutter client for the Django **GraphQL API** in this repo. It renders the
family tree as an **interactive, pan/zoomable** hierarchy and reproduces the web
app's behaviour: open a person and you see their grandfather → father → the
person → sons → grandsons; tap any node to expand it (load its parent and
children) without leaving the screen.

> Scope: this first cut focuses on the **tree rendering view** only.

## How it maps to the backend

| App action            | GraphQL query        | Backend (`main/graphql/schema.py`)                 |
| --------------------- | -------------------- | -------------------------------------------------- |
| Open a person's tree  | `person(id)` nested  | mirrors the `person_tree` view (gf→father→…→grandsons) |
| Tap a node to expand  | `connectedNodes(id)` | same query `tree.js` uses on click                 |

Node colors mirror the backend grouping (`group = "g{(parent_id) % 11}"`, see
`main/models.py`), so a branch shares a hue just like the vis.js view.

## Project layout

```
lib/
  config.dart                 # API base URL + initial person id
  models/family_node.dart     # display model + color palette (mirrors N_COLORS)
  graphql/
    graphql_client.dart       # minimal GraphQL-over-HTTP client
    family_api.dart           # bootstrap() + connectedNodes() queries
  tree/
    tree_controller.dart      # graph state + expand-on-tap logic (ChangeNotifier)
    node_widget.dart          # a single tappable person box
    tree_page.dart            # GraphView + InteractiveViewer (pan/zoom)
  main.dart
```

Layout/rendering uses the [`graphview`](https://pub.dev/packages/graphview)
package (Buchheim–Walker top-down tree); transport is plain `http`.

## Interactions

- **Tap** a node → expand (load its parent + visible children).
- **Double-tap** a node → re-center the whole tree on that person.
- **Long-press** a node → show details (designation / history) + "center here".
- Pinch / drag → zoom & pan. App bar: open-by-id, reset-zoom, reload.

## Running

1. Start the Django backend:

   ```bash
   cd familytree
   python manage.py runserver 8000
   ```

2. Point the app at it and run. Pick the base URL for your target:

   ```bash
   cd mobile

   # iOS simulator / desktop / web (same host):
   flutter run --dart-define=API_BASE_URL=http://localhost:8000

   # Android emulator (host loopback is 10.0.2.2):
   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000

   # Physical device on the same Wi-Fi:
   flutter run --dart-define=API_BASE_URL=http://<your-computer-ip>:8000
   ```

   Set the first person to open with `--dart-define=ROOT_PERSON_ID=11`
   (the in-app **person** button can open any id at runtime).

### Notes

- **Visibility**: public persons are visible anonymously. The `connectedNodes`
  expansion is filtered by the backend's `is_visible_to`, matching the web app.
- **Web (CORS)**: Flutter *web* runs from a different origin, so the browser
  sends an `OPTIONS` preflight before each GraphQL `POST`. This is handled by
  `django-cors-headers` (wired into `base.py`, with `CORS_ALLOW_ALL_ORIGINS =
  True` in `dev.py`). Native Android/iOS don't do preflight, so this only
  matters for the web target.
