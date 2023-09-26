import json

from django.http import JsonResponse
from django.shortcuts import get_object_or_404, render

from .models import Bookmark
from main.models import Person


def place_bookmark(req, id, x, y):
    if req.user.is_staff:
        bookmark = get_object_or_404(Bookmark, pk=id)
        bookmark.x = x
        bookmark.y = y
        bookmark.save()
        return JsonResponse({'result': 'bookmark new coordinates saved'})
    return JsonResponse({
        'result':
        'you don\'t have permission to change bookmark coordinates'
    })


def common_root(root, orphans):
    matched = []
    while root is not None:
        root = root.parent
        for i, _ in enumerate(orphans):
            if orphans[i] in matched:
                continue
            if orphans[i].parent is None:
                return orphans[i]
            orphans[i] = orphans[i].parent
            if orphans[i] == root:
                matched.append(root)
        if len(matched) == len(orphans):
            return root
    return None


def get_bookmark_depth(person, links):
    current_person = person
    depth = 0
    while current_person.pk in links:  # root has no link to it
        depth += 1
        link = links[current_person.pk]
        current_person = Person.objects.get(pk=link["from"])
    return depth


def index(req):
    bookmarked = [bookmark.person for bookmark in Bookmark.objects.all()]
    data = [person.as_node(forced_group=2) for person in bookmarked]
    links = {}
    root = None
    for person in bookmarked:
        parent, _ = person.find_closest_parent(bookmarked)
        if parent is None:
            root = person
            continue
        link_id = person.pk
        links[link_id] = {
            "id": link_id,
            "from": parent.pk,
            "to": person.pk,
        }

    bookmark_depths = {}
    for person in bookmarked:
        depth = get_bookmark_depth(person, links)
        if not person.pk in links:
            continue
        bookmark_depths[person.pk] = depth

    max_depth = max(bookmark_depths.values()) - 1
    width_max = 30
    width_min = 5
    for link in links.values():
        link["width"] = width_max + ((width_min - width_max) /
                                     max_depth) * (bookmark_depths[link["to"]])
    return render(req, 'main/home.html', {
        "data": json.dumps(data),
        "links": json.dumps(list(links.values()))
    })
