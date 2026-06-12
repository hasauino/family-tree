from django.urls import reverse


def test_index_renders_tree_from_get_tree(client, db, monkeypatch):
    monkeypatch.setattr("home.views.get_tree", lambda: {"data": "[1,2,3]", "links": "[]"})

    response = client.get(reverse("home:index"))

    assert response.status_code == 200
    assert response.context["data"] == "[1,2,3]"
    assert response.context["links"] == "[]"
