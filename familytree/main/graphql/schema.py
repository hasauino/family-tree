import logging

import graphene
from home.models import Bookmark
from home.types import BookmarkType

from main.graphql import account, auth, types
from main.graphql.decorators import authenticated_only, staff_only
from main.models import Person


class MutationReply:
    ok = graphene.Boolean()
    message = graphene.String()

    @staticmethod
    def success(message=""):
        return {"ok": True, "message": message}

    @staticmethod
    def fail(message=""):
        return {"ok": False, "message": message}


class Query(graphene.ObjectType):
    connected_nodes = graphene.Field(
        types.ConnectedNodes,
        description="Get all nodes connected to a node (parent and children)",
        id=graphene.Int(required=True, description="Node's ID"),
    )
    person = graphene.Field(types.PersonType, id=graphene.ID(required=True))
    tree_path = graphene.Field(
        types.TreePath,
        description="Get the chain of nodes from an ancestor down to one of their descendants",
        from_id=graphene.Int(required=True, description="Ancestor's ID"),
        to_id=graphene.Int(required=True, description="Descendant's ID"),
    )
    me = graphene.Field(
        types.CurrentUserType,
        description="The currently signed-in user (null fields when anonymous)",
    )
    auth_config = graphene.Field(
        auth.AuthConfigType,
        description="Which sign-in/sign-up methods the client should offer",
    )
    search_persons = graphene.List(
        types.PersonSearchResult,
        description="Search persons by (the start of) their name, including ancestors' names",
        query=graphene.String(required=True, description="Name to search for"),
    )
    can_delete = graphene.Boolean(
        description="Check if given person can be deleted by the current user",
        id=graphene.Int(required=True, description="Node's ID to be checked"),
    )
    delete_info = graphene.Field(
        types.DeleteInfo,
        description="Descendant count and orphan-eligibility for a potential deletion",
        id=graphene.Int(required=True),
    )
    list_bookmarks = graphene.List(BookmarkType, description="Get list of all bookmarks")
    home_tree = graphene.Field(types.HomeTree, description="Radial home tree: virtual root + tags + bookmarks")
    list_tags = graphene.List(types.TagType, description="All admin-defined tags")

    def resolve_connected_nodes(parent, info, id):
        user = info.context.user
        person = Person.objects.get(pk=id)
        children = [person.as_node(user) for person in person.children.all() if person.is_visible_to(user)]
        parent_node = None
        if person.parent is not None:
            if person.parent.is_visible_to(user):
                parent_node = person.parent.as_node(user)
        return {"parent": parent_node, "children": children}

    def resolve_person(parent, info, id):
        return Person.objects.get(pk=id)

    def resolve_tree_path(parent, info, from_id, to_id):
        """
        Connects two people in the tree. When one is an ancestor of the other,
        the route is the straight line between them; otherwise it runs up from
        each endpoint to their lowest common ancestor. Returns the route plus
        the siblings at each step (so it can be drawn in context), the parent
        -> child edges between all those nodes, and metadata describing the
        relationship (see types.TreePath).

        Returns None if either person doesn't exist or isn't visible to the
        current user, if any node on the way to the root is hidden, or if the
        two share no visible common ancestor (disconnected trees).
        """
        user = info.context.user
        from_person = Person.objects.filter(pk=from_id).first()
        to_person = Person.objects.filter(pk=to_id).first()
        if from_person is None or to_person is None:
            return None
        if not from_person.is_visible_to(user) or not to_person.is_visible_to(user):
            return None

        def ancestor_chain(person):
            """[person, parent, ..., root]; None if any node is hidden."""
            chain = []
            current = person
            while current is not None:
                if not current.is_visible_to(user):
                    return None
                chain.append(current)
                current = current.parent
            return chain

        from_chain = ancestor_chain(from_person)
        to_chain = ancestor_chain(to_person)
        if from_chain is None or to_chain is None:
            return None

        # Lowest common ancestor: walking up from `to`, the first node that is
        # also an ancestor (or self) of `from` is the deepest shared node.
        from_depth = {p.pk: i for i, p in enumerate(from_chain)}
        meeting = None
        to_generations = None
        for i, person in enumerate(to_chain):
            if person.pk in from_depth:
                meeting = person
                to_generations = i
                break
        if meeting is None:
            return None
        from_generations = from_depth[meeting.pk]

        # The route: from -> ... -> meeting -> ... -> to (no siblings).
        route = from_chain[: from_generations + 1] + list(reversed(to_chain[:to_generations]))

        # Display nodes: every route node plus its siblings, for context.
        loaded = {}

        def add(person):
            if person.pk not in loaded and person.is_visible_to(user):
                loaded[person.pk] = person

        for person in route:
            add(person)
            if person.parent is not None:
                for sibling in person.parent.children.all():
                    add(sibling)

        def depth(person):
            count = 0
            while person.parent is not None:
                count += 1
                person = person.parent
            return count

        persons = sorted(loaded.values(), key=depth)
        edges = [
            {"from_id": p.parent.pk, "to_id": p.pk} for p in persons if p.parent is not None and p.parent.pk in loaded
        ]
        return {
            "nodes": [p.as_node(user) for p in persons],
            "edges": edges,
            "path_ids": [p.pk for p in route],
            "meeting_id": meeting.pk,
            "from_generations": from_generations,
            "to_generations": to_generations,
            "is_direct": from_generations == 0 or to_generations == 0,
        }

    def resolve_me(parent, info):
        user = info.context.user
        if not user.is_authenticated:
            return {
                "id": None,
                "username": None,
                "is_staff": False,
                "is_authenticated": False,
            }
        return auth.current_user_payload(user)

    def resolve_auth_config(parent, info):
        return auth.resolve_auth_config(parent, info)

    def resolve_search_persons(parent, info, query):
        user = info.context.user
        start = query.split(" ")[0]
        results = []
        for person in Person.objects.filter(name__startswith=start):
            if user in person.editors.all() or person.access == "public" or user.is_staff:
                if query == str(person)[0 : len(query)]:
                    results.append({"id": person.id, "name": str(person)})
                    if len(results) > 5:
                        break
        return results

    @authenticated_only
    def resolve_can_delete(parent, info, id):
        return Person.objects.get(pk=id).is_editable_by(info.context.user)

    @authenticated_only
    def resolve_delete_info(parent, info, id):
        found = Person.objects.filter(pk=id)
        if not found.exists():
            return types.DeleteInfo(descendant_count=0, is_root_with_single_child=False)
        person = found.first()
        count = 0
        queue = list(person.children.all())
        while queue:
            current = queue.pop()
            count += 1
            queue.extend(list(current.children.all()))
        is_root_single = person.parent is None and person.children.count() == 1
        return types.DeleteInfo(descendant_count=count, is_root_with_single_child=is_root_single)

    @authenticated_only
    def resolve_list_bookmarks(parent, info):
        return Bookmark.objects.all()

    def resolve_home_tree(parent, info):
        from home.models import HomeSettings, Tag

        user = info.context.user
        tags = list(Tag.objects.all())
        bookmarks = list(Bookmark.objects.select_related("person", "tag").all())

        settings = HomeSettings.load()
        center_id = settings.center_person_id or 0
        node_size_config = types.NodeSizeConfig(
            max_scale=settings.node_max_scale,
            min_scale=settings.node_min_scale,
            decay=settings.node_size_decay,
            padding=settings.node_padding,
            spread_degrees=settings.node_spread_degrees,
            edge_factor=settings.node_edge_factor,
        )

        # Always include the virtual root.
        root_node = types.HomeNode(
            id=0,
            kind="root",
            label=settings.root_label or "",
            group="g0",
            opacity=1.0,
            color=settings.root_color,
            font_color=settings.root_font_color,
            font_size=settings.root_font_size,
        )
        nodes_out = [root_node]
        edges_out = []

        if not tags and not bookmarks:
            return types.HomeTree(nodes=nodes_out, edges=edges_out, center_id=0, node_size_config=node_size_config)

        # ── Tag nodes (nested rings) ──────────────────────────────────────────
        # Tags may be nested under other tags or under a bookmarked person; an
        # edge connects each tag to its parent tag (negative id), its parent
        # bookmark (positive id), or to the virtual root (0) if top-level.
        bookmarked_pks = {b.person_id for b in bookmarks}
        for i, tag in enumerate(tags):
            nodes_out.append(
                types.HomeNode(
                    id=-tag.id,  # negative to avoid collision with person PKs
                    kind="tag",
                    label=tag.name,
                    group=f"g{i % 11}",  # cycle through the colour palette
                    opacity=1.0,
                    color=tag.color,
                    font_color=tag.font_color,
                    font_size=tag.font_size,
                )
            )
            if tag.parent_id is not None:
                parent_node_id = -tag.parent_id
            elif tag.parent_bookmark_id is not None and tag.parent_bookmark_id in bookmarked_pks:
                parent_node_id = tag.parent_bookmark_id
            else:
                parent_node_id = 0
            edges_out.append(types.TreeEdge(from_id=parent_node_id, to_id=-tag.id))

        # ── Effective-tag propagation ─────────────────────────────────────────
        # A bookmark's effective tag = its own tag (if set) OR the effective
        # tag of its closest bookmarked ancestor.  This lets admins tag only
        # the root bookmark of a branch; descendants inherit the tag.
        all_bookmarked_persons = [b.person for b in bookmarks]
        bm_by_pk = {b.person.pk: b for b in bookmarks}

        # closest bookmarked parent within the bookmark set
        parent_in_bm_tree = {}
        for person in all_bookmarked_persons:
            bm_parent, _ = person.find_closest_parent(all_bookmarked_persons)
            if bm_parent:
                parent_in_bm_tree[person.pk] = bm_parent.pk

        effective_tag_cache = {}

        def effective_tag(pk, _seen=None):
            if pk in effective_tag_cache:
                return effective_tag_cache[pk]
            _seen = _seen or set()
            if pk in _seen:
                effective_tag_cache[pk] = None
                return None
            _seen.add(pk)
            bm = bm_by_pk.get(pk)
            if bm is None:
                return None
            if bm.tag_id is not None:
                effective_tag_cache[pk] = bm.tag_id
                return bm.tag_id
            par_pk = parent_in_bm_tree.get(pk)
            result = effective_tag(par_pk, _seen) if par_pk is not None else None
            effective_tag_cache[pk] = result
            return result

        for bm in bookmarks:
            effective_tag(bm.person.pk)

        # ── Bookmark nodes ────────────────────────────────────────────────────
        for bm in bookmarks:
            person = bm.person
            raw = person.as_node(user)
            nodes_out.append(
                types.HomeNode(
                    id=person.pk,
                    kind="bookmark",
                    # Only the home-center bookmark may override its label text
                    # (shown inside its bubble); every other bookmark keeps the
                    # person's name and renders as an initial.
                    label=bm.label if (person.pk == center_id and bm.label) else raw.get("label", person.name),
                    group=raw.get("group", "g0"),
                    title=raw.get("title"),
                    opacity=raw.get("opacity", 1.0),
                    color=bm.color,
                    font_color=bm.font_color,
                    font_size=bm.font_size,
                )
            )

            et = effective_tag_cache.get(person.pk)
            par_pk = parent_in_bm_tree.get(person.pk)

            if par_pk is not None:
                par_et = effective_tag_cache.get(par_pk)
                if et == par_et:
                    # Same effective tag as parent → connect directly to parent bookmark
                    edges_out.append(types.TreeEdge(from_id=par_pk, to_id=person.pk))
                elif et is not None:
                    # This bookmark breaks the chain (own tag differs) → root of its tag
                    edges_out.append(types.TreeEdge(from_id=-et, to_id=person.pk))
                else:
                    # No effective tag and parent has a tag → floating under root
                    edges_out.append(types.TreeEdge(from_id=0, to_id=person.pk))
            else:
                # No bookmarked parent
                if et is not None:
                    edges_out.append(types.TreeEdge(from_id=-et, to_id=person.pk))
                else:
                    edges_out.append(types.TreeEdge(from_id=0, to_id=person.pk))

        return types.HomeTree(nodes=nodes_out, edges=edges_out, center_id=center_id, node_size_config=node_size_config)

    def resolve_list_tags(parent, info):
        from home.models import Tag

        return [types.TagType(id=t.id, name=t.name, parent_id=t.parent_id) for t in Tag.objects.all()]


class AddPerson(graphene.Mutation, MutationReply, types.NodeType):
    class Arguments:
        id = graphene.Int(required=True, description="ID of the parent")
        child_name = graphene.String(required=True, description="Name of the new child")

    @authenticated_only
    def mutate(root, info, id, child_name):
        if len(child_name) < 1:
            return MutationReply.fail("Invalid child name, cannot be empty string")
        logging.debug(f"Called add person mutation with id: {id}")
        user = info.context.user
        found = Person.objects.filter(pk=id)
        if not found.exists():
            return MutationReply.fail(f"Person with ID ${id} does not exist")
        person = found.first()
        found = person.children.filter(name=child_name)
        child = None
        if found.exists():
            child = found.first()
        else:
            child = Person(name=child_name, parent=person, access="private")
            child.save()
        if user.is_staff:
            child.access = "public"
        child.editors.add(user)
        child.save()
        return {**MutationReply.success(), **child.as_node(user)}


class EditPerson(graphene.Mutation, MutationReply, types.NodeType):
    class Arguments:
        id = graphene.Int(required=True, description="ID of the person to edit")
        name = graphene.String(required=False, description="New name (omit to keep)")
        designation = graphene.String(required=False, description="New designation (omit to keep)")
        history = graphene.String(required=False, description="New historical background (omit to keep)")

    @authenticated_only
    def mutate(root, info, id, name=None, designation=None, history=None):
        logging.debug(f"Called edit person mutation with id: {id}")
        user = info.context.user
        found = Person.objects.filter(pk=id)
        if not found.exists():
            return MutationReply.fail(f"Person with ID ${id} does not exist")
        person = found.first()
        # Same rule as the web save view: staff or one of the person's editors.
        if not (user.is_staff or user in person.editors.all()):
            return MutationReply.fail(f"Person with ID ${id} cannot be edited by current user")
        if name is not None:
            if len(name) < 1:
                return MutationReply.fail("Invalid name, cannot be empty string")
            person.name = name
        if designation is not None:
            person.designation = designation
        if history is not None:
            person.history = history
        person.save()
        return {**MutationReply.success(), **person.as_node(user)}


class DeletePerson(graphene.Mutation, MutationReply):
    class Arguments:
        id = graphene.Int(required=True)

    @authenticated_only
    def mutate(root, info, id):
        logging.debug(f"Called delete person mutation with id: {id}")
        user = info.context.user
        found = Person.objects.filter(pk=id)
        if not found.exists():
            return MutationReply.fail(f"Person with ID ${id} does not exist")
        person = found.first()
        if not person.is_editable_by(user):
            return MutationReply.fail(f"Person with ID ${id} cannot be deleted by current user")
        if person.parent is None and person.children.count() == 1:
            child = person.children.first()
            child.parent = None
            child.save()
        if user.is_staff:
            person.delete()
        else:
            person.editors.remove(user)
            person.save()
            if person.access == "private" and len(person.editors.all()) == 0:
                person.delete()
        return MutationReply.success()


class BookmarkPerson(graphene.Mutation, MutationReply):
    class Arguments:
        id = graphene.Int(required=True)

    @staff_only
    def mutate(root, info, id):
        logging.debug(f"Called bookmark person mutation with id: {id}")
        user = info.context.user
        found = Person.objects.filter(pk=id)
        if not found.exists():
            return MutationReply.fail(f"Person with ID ${id} does not exist")
        person = found.first()
        if not person.is_public():
            return MutationReply.fail("Cannot bookmark private person")
        if not user.is_staff:
            return MutationReply.fail("Current user is not a staff, cannot bookmark person")
        if not Bookmark.objects.filter(person=person).exists():
            bookmark = Bookmark(person=person)
            bookmark.save()
        return MutationReply.success()


class UnBookmarkPerson(graphene.Mutation, MutationReply):
    class Arguments:
        id = graphene.Int(required=True)

    @staff_only
    def mutate(root, info, id):
        logging.debug(f"Called un-bookmark person mutation with id: {id}")
        user = info.context.user
        found = Person.objects.filter(pk=id)
        if not found.exists():
            return MutationReply.fail(f"Person with ID ${id} does not exist")
        person = found.first()
        if not user.is_staff:
            return MutationReply.fail("Current user is not a staff, cannot un-bookmark person")
        person.bookmark.delete()
        return MutationReply.success()


class PublishPerson(graphene.Mutation, MutationReply):
    class Arguments:
        id = graphene.Int(required=True)

    @staff_only
    def mutate(root, info, id):
        logging.debug(f"Called publish person mutation with id: {id}")
        user = info.context.user
        found = Person.objects.filter(pk=id)
        if not found.exists():
            return MutationReply.fail(f"Person with ID ${id} does not exist")
        person = found.first()
        if not user.is_staff:
            return MutationReply.fail("Current user is not a staff, cannot publish person")
        person.access = "public"
        person.editors.add(user)
        person.save()
        for child in person.children.all():
            child.access = "public"
            child.editors.add(user)
            child.save()
        return MutationReply.success()


class UnPublishPerson(graphene.Mutation, MutationReply):
    class Arguments:
        id = graphene.Int(required=True)

    @staff_only
    def mutate(root, info, id):
        logging.debug(f"Called unpublish person mutation with id: {id}")
        user = info.context.user
        found = Person.objects.filter(pk=id)
        if not found.exists():
            return MutationReply.fail(f"Person with ID ${id} does not exist")
        person = found.first()
        if not user.is_staff:
            return MutationReply.fail("Current user is not a staff, cannot unpublish person")
        person.access = "private"
        person.remove_editor(user)
        person.save()
        Bookmark.objects.filter(person=person).delete()
        for child in person.children.all():
            child.access = "private"
            child.remove_editor(user)
            child.save()
            Bookmark.objects.filter(person=child).delete()
        return MutationReply.success()


class EditBookmark(graphene.Mutation, MutationReply):
    class Arguments:
        id = graphene.Int(
            required=True, description="ID of the person associated with the bookmark (not bookmark's ID)"
        )
        label = graphene.String(required=False, description="Overwrite default label (person's name)")
        color = graphene.String(
            required=False,
            description="Overwrite default color. "
            "It should be an HTML color hex value without the leading #. "
            "Example: ff0011",
        )
        font_color = graphene.String(
            required=False,
            description="Overwrite default font color. "
            "It should be an HTML color hex value without the leading #. "
            "Example: ff0011. Empty string to reset",
        )
        font_size = graphene.Float(required=False, description="Overwrite default font size. Set to -1 to reset")

    @staff_only
    def mutate(root, info, id, label=None, color=None, font_color=None, font_size=None):
        bookmark = Bookmark.objects.get(person__pk=id)
        if font_size == -1:
            bookmark.font_size = None
            font_size = None
        fields = {"label": label, "color": color, "font_color": font_color, "font_size": font_size}
        for key, value in fields.items():
            if value is not None:
                setattr(bookmark, key, value)
        bookmark.save()
        return MutationReply.success()


class AddParent(graphene.Mutation, MutationReply, types.NodeType):
    class Arguments:
        id = graphene.Int(required=True, description="ID of the person to add a parent to")
        parent_name = graphene.String(required=True, description="Name of the new parent node")

    @authenticated_only
    def mutate(root, info, id, parent_name):
        if len(parent_name.strip()) < 1:
            return MutationReply.fail("Invalid parent name, cannot be empty string")
        user = info.context.user
        found = Person.objects.filter(pk=id)
        if not found.exists():
            return MutationReply.fail(f"Person with ID {id} does not exist")
        person = found.first()
        if not (user.is_staff or user in person.editors.all()):
            return MutationReply.fail("You do not have permission to add a parent to this person")
        if person.parent is not None:
            return MutationReply.fail("This person already has a parent")
        new_parent = Person(name=parent_name.strip(), parent=None, access="private")
        new_parent.save()
        if user.is_staff:
            new_parent.access = "public"
        new_parent.editors.add(user)
        new_parent.save()
        person.parent = new_parent
        person.save()
        return {**MutationReply.success(), **new_parent.as_node(user)}


class AddChildren(graphene.Mutation):
    class Arguments:
        id = graphene.Int(required=True, description="ID of the parent")
        child_names = graphene.List(graphene.NonNull(graphene.String), required=True)

    nodes = graphene.List(types.NodeType)
    warnings = graphene.List(graphene.String)
    ok = graphene.Boolean()
    message = graphene.String()

    @authenticated_only
    def mutate(root, info, id, child_names):
        if not child_names:
            return AddChildren(ok=False, message="No names provided", nodes=[], warnings=[])
        user = info.context.user
        found = Person.objects.filter(pk=id)
        if not found.exists():
            return AddChildren(ok=False, message=f"Person with ID {id} does not exist", nodes=[], warnings=[])
        parent = found.first()
        nodes = []
        warnings = []
        for name in child_names:
            name = name.strip()
            if not name:
                continue
            existing = parent.children.filter(name=name)
            if existing.exists():
                warnings.append(name)
                child = existing.first()
            else:
                child = Person(name=name, parent=parent, access="private")
                child.save()
            if user.is_staff:
                child.access = "public"
            child.editors.add(user)
            child.save()
            nodes.append(child.as_node(user))
        return AddChildren(ok=True, nodes=nodes, warnings=warnings, message="")


class MovePerson(graphene.Mutation, MutationReply, types.NodeType):
    class Arguments:
        id = graphene.Int(required=True, description="ID of the person to move")
        new_parent_id = graphene.Int(required=True, description="ID of the new parent")

    @authenticated_only
    def mutate(root, info, id, new_parent_id):
        user = info.context.user
        found = Person.objects.filter(pk=id)
        if not found.exists():
            return MutationReply.fail(f"Person with ID {id} does not exist")
        person = found.first()
        if not (user.is_staff or user in person.editors.all()):
            return MutationReply.fail("You do not have permission to move this person")
        found = Person.objects.filter(pk=new_parent_id)
        if not found.exists():
            return MutationReply.fail(f"Person with ID {new_parent_id} does not exist")
        new_parent = found.first()
        # Prevent cycles: walk up from new_parent to ensure person is not an ancestor
        current = new_parent
        while current is not None:
            if current.pk == person.pk:
                return MutationReply.fail("Cannot move a person to be a descendant of themselves")
            current = current.parent
        person.parent = new_parent
        person.save()
        return {**MutationReply.success(), **person.as_node(user)}


class CreateTag(graphene.Mutation, MutationReply):
    class Arguments:
        name = graphene.String(required=True)
        parent_node_id = graphene.Int(
            required=False,
            description="Optional parent home-tree node ID: a negative tag ID, "
            "a positive bookmarked person ID, or null/0 for top-level.",
        )

    id = graphene.Int()
    name = graphene.String()

    @staff_only
    def mutate(root, info, name, parent_node_id=None):
        from home.models import Tag

        if not name.strip():
            return {**MutationReply.fail("Tag name cannot be empty"), "id": None, "name": None}
        parent = None
        parent_bookmark = None
        if parent_node_id is not None and parent_node_id != 0:
            if parent_node_id < 0:
                parent = Tag.objects.filter(pk=-parent_node_id).first()
                if parent is None:
                    return {**MutationReply.fail(f"Tag {-parent_node_id} not found"), "id": None, "name": None}
            else:
                if not Bookmark.objects.filter(person__pk=parent_node_id).exists():
                    return {
                        **MutationReply.fail(f"No bookmark for person {parent_node_id}"),
                        "id": None,
                        "name": None,
                    }
                parent_bookmark_id = parent_node_id
                parent_bookmark = Person.objects.filter(pk=parent_bookmark_id).first()
        tag = Tag.objects.create(name=name.strip(), parent=parent, parent_bookmark=parent_bookmark)
        return {**MutationReply.success(), "id": tag.id, "name": tag.name}


class RenameTag(graphene.Mutation, MutationReply):
    class Arguments:
        id = graphene.Int(required=True)
        name = graphene.String(required=True)

    @staff_only
    def mutate(root, info, id, name):
        from home.models import Tag

        if not name.strip():
            return MutationReply.fail("Tag name cannot be empty")
        tag = Tag.objects.filter(pk=id).first()
        if tag is None:
            return MutationReply.fail(f"Tag {id} not found")
        tag.name = name.strip()
        tag.save()
        return MutationReply.success()


class MoveTag(graphene.Mutation, MutationReply):
    """Re-parent a tag, placing it under another tag, under a bookmarked person, or
    under the root if parentNodeId is null/0."""

    class Arguments:
        id = graphene.Int(required=True)
        parent_node_id = graphene.Int(
            required=False,
            description="New parent home-tree node ID: a negative tag ID, "
            "a positive bookmarked person ID, or null/0 for top-level.",
        )

    @staff_only
    def mutate(root, info, id, parent_node_id=None):
        from home.models import Tag

        tag = Tag.objects.filter(pk=id).first()
        if tag is None:
            return MutationReply.fail(f"Tag {id} not found")

        if parent_node_id is not None and parent_node_id != 0:
            if parent_node_id < 0:
                parent_id = -parent_node_id
                if parent_id == id:
                    return MutationReply.fail("A tag cannot be its own parent")
                new_parent = Tag.objects.filter(pk=parent_id).first()
                if new_parent is None:
                    return MutationReply.fail(f"Tag {parent_id} not found")
                # Walk up from new_parent: if we reach `tag`, this would create a cycle.
                ancestor = new_parent
                while ancestor is not None:
                    if ancestor.pk == tag.pk:
                        return MutationReply.fail("Cannot move a tag under one of its own descendants")
                    ancestor = ancestor.parent
                tag.parent = new_parent
                tag.parent_bookmark = None
            else:
                if not Bookmark.objects.filter(person__pk=parent_node_id).exists():
                    return MutationReply.fail(f"No bookmark for person {parent_node_id}")
                tag.parent = None
                tag.parent_bookmark_id = parent_node_id
        else:
            tag.parent = None
            tag.parent_bookmark = None
        tag.save()
        return MutationReply.success()


class DeleteTag(graphene.Mutation, MutationReply):
    class Arguments:
        id = graphene.Int(required=True)

    @staff_only
    def mutate(root, info, id):
        from home.models import Tag

        Tag.objects.filter(pk=id).delete()  # bookmarks/child tags → SET_NULL automatically
        return MutationReply.success()


class SetTagStyle(graphene.Mutation, MutationReply):
    """Configure a tag's color, font color, and font size. Pass an empty string for
    color/font_color or -1 for font_size to reset to the default."""

    class Arguments:
        id = graphene.Int(required=True)
        color = graphene.String(
            required=False,
            description="Overwrite default color. "
            "It should be an HTML color hex value without the leading #. "
            "Empty string to reset.",
        )
        font_color = graphene.String(
            required=False,
            description="Overwrite default font color. "
            "It should be an HTML color hex value without the leading #. "
            "Empty string to reset.",
        )
        font_size = graphene.Float(required=False, description="Overwrite default font size. Set to -1 to reset")

    @staff_only
    def mutate(root, info, id, color=None, font_color=None, font_size=None):
        from home.models import Tag

        tag = Tag.objects.filter(pk=id).first()
        if tag is None:
            return MutationReply.fail(f"Tag {id} not found")

        if font_size == -1:
            tag.font_size = None
            font_size = None
        if color == "":
            tag.color = None
            color = None
        if font_color == "":
            tag.font_color = None
            font_color = None

        fields = {"color": color, "font_color": font_color, "font_size": font_size}
        for key, value in fields.items():
            if value is not None:
                setattr(tag, key, value)
        tag.save()
        return MutationReply.success()


class SetBookmarkTag(graphene.Mutation, MutationReply):
    """Assign (or clear) the tag of a bookmark.  Pass tagId=null to untag."""

    class Arguments:
        person_id = graphene.Int(required=True)
        tag_id = graphene.Int()  # nullable → untag

    @staff_only
    def mutate(root, info, person_id, tag_id=None):
        bookmark = Bookmark.objects.filter(person__pk=person_id).first()
        if bookmark is None:
            return MutationReply.fail(f"No bookmark for person {person_id}")
        bookmark.tag_id = tag_id
        bookmark.save()
        return MutationReply.success()


class SetHomeCenter(graphene.Mutation, MutationReply):
    """Set (or clear) the bookmark used as the center of the home tree.  Pass personId=null to reset."""

    class Arguments:
        person_id = graphene.Int()  # nullable → reset to default

    @staff_only
    def mutate(root, info, person_id=None):
        from home.models import HomeSettings

        if person_id is not None:
            bookmark = Bookmark.objects.filter(person__pk=person_id).first()
            if bookmark is None:
                return MutationReply.fail(f"No bookmark for person {person_id}")

        settings = HomeSettings.load()
        settings.center_person_id = person_id
        settings.save()
        return MutationReply.success()


class SetNodeSizeConfig(graphene.Mutation, MutationReply):
    """Configure how home-tree node size scales with depth from the global root."""

    class Arguments:
        max_scale = graphene.Float(required=True, description="Visual scale of nodes at the root.")
        min_scale = graphene.Float(required=True, description="Visual scale of the deepest (leaf) nodes.")
        decay = graphene.Float(
            required=True, description="How quickly node size shrinks per generation away from the root."
        )
        padding = graphene.Float(
            required=False, description="Gap kept between a node disk and its parent/siblings when packing the tree."
        )
        spread_degrees = graphene.Float(
            required=False, description="Preferred fan breadth (degrees) a node spreads its children over."
        )
        edge_factor = graphene.Float(
            required=False, description="Cap on parent->child distance, as a multiple of the minimum spacing."
        )

    @staff_only
    def mutate(root, info, max_scale, min_scale, decay, padding=None, spread_degrees=None, edge_factor=None):
        from home.models import HomeSettings

        if min_scale <= 0 or max_scale <= 0:
            return MutationReply.fail("Scales must be greater than 0")
        if min_scale > max_scale:
            return MutationReply.fail("Min scale cannot be greater than max scale")
        if decay < 0:
            return MutationReply.fail("Decay cannot be negative")
        if padding is not None and padding < 0:
            return MutationReply.fail("Padding cannot be negative")
        if spread_degrees is not None and not (0 < spread_degrees <= 360):
            return MutationReply.fail("Spread angle must be between 0 and 360 degrees")
        if edge_factor is not None and edge_factor < 1:
            return MutationReply.fail("Max edge length must be at least 1")

        settings = HomeSettings.load()
        settings.node_max_scale = max_scale
        settings.node_min_scale = min_scale
        settings.node_size_decay = decay
        if padding is not None:
            settings.node_padding = padding
        if spread_degrees is not None:
            settings.node_spread_degrees = spread_degrees
        if edge_factor is not None:
            settings.node_edge_factor = edge_factor
        settings.save()
        return MutationReply.success()


class SetRootStyle(graphene.Mutation, MutationReply):
    """Configure the central root node's label, color, font color, and font size.
    Pass an empty string for label/color/font_color or -1 for font_size to reset."""

    class Arguments:
        label = graphene.String(
            required=False, description="Text shown on the root node. Empty string to reset to the default icon."
        )
        color = graphene.String(
            required=False,
            description="Overwrite default color. "
            "It should be an HTML color hex value without the leading #. "
            "Empty string to reset.",
        )
        font_color = graphene.String(
            required=False,
            description="Overwrite default font color. "
            "It should be an HTML color hex value without the leading #. "
            "Empty string to reset.",
        )
        font_size = graphene.Float(required=False, description="Overwrite default font size. Set to -1 to reset")

    @staff_only
    def mutate(root, info, label=None, color=None, font_color=None, font_size=None):
        from home.models import HomeSettings

        settings = HomeSettings.load()
        if font_size == -1:
            settings.root_font_size = None
            font_size = None
        if label == "":
            settings.root_label = None
            label = None
        if color == "":
            settings.root_color = None
            color = None
        if font_color == "":
            settings.root_font_color = None
            font_color = None

        fields = {
            "root_label": label,
            "root_color": color,
            "root_font_color": font_color,
            "root_font_size": font_size,
        }
        for key, value in fields.items():
            if value is not None:
                setattr(settings, key, value)
        settings.save()
        return MutationReply.success()


class Mutations(graphene.ObjectType):
    password_login = auth.PasswordLogin.Field()
    social_login = auth.SocialLogin.Field()
    register_email = auth.RegisterEmail.Field()
    verify_email_code = auth.VerifyEmailCode.Field()
    resend_code = auth.ResendCode.Field()
    request_password_reset = auth.RequestPasswordReset.Field()
    reset_password = auth.ResetPassword.Field()
    update_profile = account.UpdateProfile.Field()
    upload_profile_image = account.UploadProfileImage.Field()
    remove_profile_image = account.RemoveProfileImage.Field()
    delete_account = account.DeleteAccount.Field()
    add_person = AddPerson.Field()
    add_parent = AddParent.Field()
    add_children = AddChildren.Field()
    move_person = MovePerson.Field()
    edit_person = EditPerson.Field()
    delete_person = DeletePerson.Field()
    bookmark_person = BookmarkPerson.Field()
    unbookmark_person = UnBookmarkPerson.Field()
    publish_person = PublishPerson.Field()
    unpublish_person = UnPublishPerson.Field()
    edit_bookmark = EditBookmark.Field()
    create_tag = CreateTag.Field()
    rename_tag = RenameTag.Field()
    move_tag = MoveTag.Field()
    delete_tag = DeleteTag.Field()
    set_tag_style = SetTagStyle.Field()
    set_bookmark_tag = SetBookmarkTag.Field()
    set_home_center = SetHomeCenter.Field()
    set_node_size_config = SetNodeSizeConfig.Field()
    set_root_style = SetRootStyle.Field()


schema = graphene.Schema(query=Query, mutation=Mutations)
