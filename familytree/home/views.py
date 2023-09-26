import json

from django.http import JsonResponse
from django.shortcuts import get_object_or_404, render

from .models import Bookmark


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


def index(req):
    bookmarks = Bookmark.objects.all()
    data = [bookmark.person.as_node(forced_group=2) for bookmark in bookmarks]
    links = []
    visited_persons = [bookmarks[0].person]
    bookmark_depths = {bookmarks[0].person.pk: 0}
    for bookmark in bookmarks[1:]:
        parent, _ = bookmark.person.find_closest_parent(visited_persons)
        if parent is None:
            continue
        bookmark_depths[bookmark.person.pk] = bookmark_depths[parent.pk] + 1
        links.append({
            "id": bookmark.person.pk,
            "from": parent.pk,
            "to": bookmark.person.pk,
        })
        visited_persons.append(bookmark.person)
    max_depth = max(bookmark_depths.values()) - 1
    width_max = 30
    width_min = 5
    for link in links:
        link["width"] = width_max + ((width_min - width_max) /
                                     max_depth) * (bookmark_depths[link["from"]])
    return render(req, 'main/home.html', {
        "data": json.dumps(data),
        "links": json.dumps(links)
    })
