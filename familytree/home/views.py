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


def find_common_root(nodes):
    """
    Given a set of persons (nodes), it will return the 
    closest common root to all of them
    """
    persons = list(set(nodes))
    visited = []
    matched = []
    while len(matched) < len(persons):
        for i, _ in enumerate(persons):
            if persons[i] in matched:
                continue
            parent = persons[i].parent
            if parent is None:
                return persons[i]
            if parent in visited:
                matched.append(persons[i])
            visited.append(persons[i])
            persons[i] = parent
    if len(matched) > 0:
        for p in matched:
            print(p)
        return matched[-1]
    return None


def get_bookmark_depth(person, links):
    current_person = person
    depth = 0
    while current_person.pk in links:  # root has no link to it
        depth += 1
        link = links[current_person.pk]
        current_person = Person.objects.get(pk=link["from"])
    return depth


def calculate_link_width(width_min, width_max, tree_depth, link_depth):
    slope = (width_max - width_min) / (1 - tree_depth)
    c = (tree_depth * width_max - width_min) / (tree_depth - 1)
    return slope * link_depth + c


def index(req):
    bookmarked = list({bookmark.person for bookmark in Bookmark.objects.all()})
    data = [person.as_node(forced_group=2) for person in bookmarked]
    links = dict()
    orphans = []
    for person in bookmarked:
        parent, _ = person.find_closest_parent(bookmarked)
        if parent is None:
            orphans.append(person)
            continue
        links[person.pk] = {
            "id": person.pk,
            "from": parent.pk,
            "to": person.pk,
        }
    if len(orphans) > 1:  # current root is among orphans
        common_root = find_common_root(orphans)
        bookmarked.append(common_root)
        data.append(common_root.as_node(forced_group=2))
        for person in orphans:
            links[person.pk] = {
                "id": person.pk,
                "from": common_root.pk,
                "to": person.pk,
            }
    bookmark_depths = {}
    for person in bookmarked:
        depth = get_bookmark_depth(person, links)
        if not person.pk in links:
            continue
        bookmark_depths[person.pk] = depth
    tree_depth = max(bookmark_depths.values())
    for link in links.values():
        link["width"] = calculate_link_width(
            width_max=30,
            width_min=5,
            tree_depth=tree_depth,
            link_depth=bookmark_depths[link["to"]],
        )
    return render(req, 'main/home.html', {
        "data": json.dumps(data),
        "links": json.dumps(list(links.values()))
    })
