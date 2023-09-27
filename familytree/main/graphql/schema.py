import logging

import graphene

from main.graphql import types
from main.models import Person
from home.models import Bookmark
from home.types import BookmarkType


def authenticated_only(function):

    def wrapper(root, info, **args):
        if not info.context.user.is_authenticated:
            raise Exception(
                "Access Denied! you must be a logged in user to access this API"
            )
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
    can_delete = graphene.Boolean(
        description="Check if given person can be deleted by the current user",
        id=graphene.Int(required=True, description="Node's ID to be checked"),
    )
    list_bookmarks = graphene.List(BookmarkType,
                                   description="Get lis of bookmarks")

    def resolve_connected_nodes(parent, info, id):
        user = info.context.user
        person = Person.objects.get(pk=id)
        children = [
            person.as_node(user) for person in person.children.all()
            if person.is_visible_to(user)
        ]
        parent_node = None
        if person.parent is not None:
            if person.parent.is_visible_to(user):
                parent_node = person.parent.as_node(user)
        return {"parent": parent_node, "children": children}

    def resolve_person(parent, info, id):
        return Person.objects.get(pk=id)

    @authenticated_only
    def resolve_can_delete(parent, info, id):
        return Person.objects.get(pk=id).is_editable_by(info.context.user)

    @authenticated_only
    def resolve_list_bookmarks(parent, info):
        return Bookmark.objects.all()


class AddPerson(graphene.Mutation, MutationReply, types.NodeType):

    class Arguments:
        id = graphene.Int(required=True, description="ID of the parent")
        child_name = graphene.String(required=True,
                                     description="Name of the new child")

    @authenticated_only
    def mutate(root, info, id, child_name):
        if len(child_name) < 1:
            return MutationReply.fail(
                "Invalid child name, cannot be empty string")
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
            return MutationReply.fail(
                f"Person with ID ${id} cannot be deleted by current user")
        if user.is_staff:
            person.delete()
        else:
            person.editors.remove(user)
            person.save()
            if person.access == 'private' and len(person.editors.all()) == 0:
                person.delete()
        return MutationReply.success()


class BookmarkPerson(graphene.Mutation, MutationReply):

    class Arguments:
        id = graphene.Int(required=True)

    @authenticated_only
    def mutate(root, info, id):
        logging.debug(f"Called bookmark person mutation with id: {id}")
        user = info.context.user
        found = Person.objects.filter(pk=id)
        if not found.exists():
            return MutationReply.fail(f"Person with ID ${id} does not exist")
        person = found.first()
        if not user.is_staff:
            return MutationReply.fail(
                "Current user is not a staff, cannot bookmark person")
        if not Bookmark.objects.filter(person=person).exists():
            bookmark = Bookmark(person=person)
            bookmark.save()
        return MutationReply.success()


class UnBookmarkPerson(graphene.Mutation, MutationReply):

    class Arguments:
        id = graphene.Int(required=True)

    @authenticated_only
    def mutate(root, info, id):
        logging.debug(f"Called un-bookmark person mutation with id: {id}")
        user = info.context.user
        found = Person.objects.filter(pk=id)
        if not found.exists():
            return MutationReply.fail(f"Person with ID ${id} does not exist")
        person = found.first()
        if not user.is_staff:
            return MutationReply.fail(
                "Current user is not a staff, cannot un-bookmark person")
        person.bookmark_set.all()[0].delete()
        return MutationReply.success()


class PublishPerson(graphene.Mutation, MutationReply):

    class Arguments:
        id = graphene.Int(required=True)

    @authenticated_only
    def mutate(root, info, id):
        logging.debug(f"Called publish person mutation with id: {id}")
        user = info.context.user
        found = Person.objects.filter(pk=id)
        if not found.exists():
            return MutationReply.fail(f"Person with ID ${id} does not exist")
        person = found.first()
        if not user.is_staff:
            return MutationReply.fail(
                "Current user is not a staff, cannot publish person")
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

    @authenticated_only
    def mutate(root, info, id):
        logging.debug(f"Called unpublish person mutation with id: {id}")
        user = info.context.user
        found = Person.objects.filter(pk=id)
        if not found.exists():
            return MutationReply.fail(f"Person with ID ${id} does not exist")
        person = found.first()
        if not user.is_staff:
            return MutationReply.fail(
                "Current user is not a staff, cannot unpublish person")
        person.access = "private"
        person.editors.remove(user)
        person.save()
        for child in person.children.all():
            child.access = "private"
            child.editors.add(user)
            child.save()
        return MutationReply.success()


class EditBookmark(graphene.Mutation, MutationReply):

    class Arguments:
        id = graphene.Int(required=True)
        label = graphene.String(
            required=False,
            description="Overwrite default label (person's name)")
        color = graphene.String(
            required=False,
            description="Overwrite default color. "
            "It should be an HTML color hex value without the leading #. "
            "Example: ff0011")
        font_color = graphene.String(
            required=False,
            description="Overwrite default font color. "
            "It should be an HTML color hex value without the leading #. "
            "Example: ff0011. Empty string to reset",
        )
        font_size = graphene.Float(required=False,
                                   description="Overwrite default font size. Set to -1 to reset")

    @authenticated_only
    def mutate(root,
               info,
               id,
               label=None,
               color=None,
               font_color=None,
               font_size=None):
        bookmark = Bookmark.objects.get(pk=id)
        if font_size == -1:
            bookmark.font_size = None
            font_size = None
        fields = {
            "label": label,
            "color": color,
            "font_color": font_color,
            "font_size": font_size
        }
        for key, value in fields.items():
            if value is not None:
                setattr(bookmark, key, value)
        bookmark.save()
        return MutationReply.success()


class Mutations(graphene.ObjectType):
    add_person = AddPerson.Field()
    delete_person = DeletePerson.Field()
    bookmark_person = BookmarkPerson.Field()
    unbookmark_person = UnBookmarkPerson.Field()
    publish_person = PublishPerson.Field()
    unpublish_person = UnPublishPerson.Field()
    edit_bookmark = EditBookmark.Field()


schema = graphene.Schema(query=Query, mutation=Mutations)
