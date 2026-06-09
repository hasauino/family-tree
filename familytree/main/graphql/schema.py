import logging

import graphene
from home.models import Bookmark
from home.types import BookmarkType

from main.graphql import types
from main.models import Person


def authenticated_only(function):

    def wrapper(root, info, **args):
        if not info.context.user.is_authenticated:
            raise Exception("Access Denied! you must be a logged in user to access this API")
        return function(root, info, **args)

    return wrapper


def staff_only(function):

    def wrapper(root, info, **args):
        if not info.context.user.is_staff:
            raise Exception("Access Denied! you must be a logged in user to access this API")
        return function(root, info, **args)

    return wrapper


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
        Mirrors the web `tree_from_to` view: walks up from the descendant to
        the ancestor, collecting each step's siblings as a level, then returns
        those levels (root-first) as nodes plus the parent -> child edges
        between them. Returns None if either person doesn't exist, isn't
        visible to the current user, or the first isn't an ancestor of the
        second.
        """
        user = info.context.user
        found = Person.objects.filter(pk=from_id)
        if not found.exists():
            return None
        from_person = found.first()
        found = Person.objects.filter(pk=to_id)
        if not found.exists():
            return None
        to_person = found.first()
        if not from_person.is_visible_to(user):
            return None

        levels = []
        person = to_person
        while person != from_person:
            if not person.is_visible_to(user) or person.parent is None:
                return None
            levels.append([sibling for sibling in person.parent.children.all()])
            person = person.parent
        levels.append([from_person])

        all_persons = [p for level in levels[::-1] for p in level if p.is_visible_to(user)]
        return {
            "nodes": [p.as_node(user) for p in all_persons],
            "edges": [{"from_id": p.parent.pk, "to_id": p.pk} for p in all_persons[1:]],
        }

    def resolve_me(parent, info):
        user = info.context.user
        return {
            "id": user.id if user.is_authenticated else None,
            "username": user.get_username() if user.is_authenticated else None,
            "is_staff": user.is_staff,
            "is_authenticated": user.is_authenticated,
        }

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


class Mutations(graphene.ObjectType):
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


schema = graphene.Schema(query=Query, mutation=Mutations)
