import json
import logging

from home.models import Bookmark
from main.models import Person

_home_tree = None


def get_tree():
    """
    Returns the previously generated tree if any,
    otherwise generate a new one

    Tree is generated on every save/delete to a bookmark, check the ./signals.py
    """
    global _home_tree
    if _home_tree is None:
        generate_home_tree()
    return _home_tree


def generate_home_tree():
    """
    Generates a tree from the bookmarks.
    Then stores it in the global variable _home_tree
    """
    logging.info("Generating home tree")
    global _home_tree
    bookmarks = Bookmark.objects.all()
    bookmarked_persons = [bookmark.person for bookmark in bookmarks]
    data = [bookmark.as_node(forced_group=2) for bookmark in bookmarks]
    links = dict()
    orphans = []
    for person in bookmarked_persons:
        parent, _ = person.find_closest_parent(bookmarked_persons)
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
        bookmarked_persons.append(common_root)
        data.append(common_root.as_node(forced_group=2))
        for person in orphans:
            links[person.pk] = {
                "id": person.pk,
                "from": common_root.pk,
                "to": person.pk,
            }
    bookmark_depths = {}
    for person in bookmarked_persons:
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
    _home_tree = {
        "data": json.dumps(data),
        "links": json.dumps(list(links.values()))
    }


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
