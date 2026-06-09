import graphene
from graphene_django import DjangoObjectType

from main.models import Person, User


class PersonType(DjangoObjectType):
    published = graphene.Boolean(description="It shows whether the person has been approved/published by a staff user")
    bookmarked = graphene.Boolean(
        description="It shows whether the person has been bookmarked (shown on home page) by a staff user"
    )

    class Meta:
        model = Person
        fields = [
            "id",
            "name",
            "parent",
            "children",
            "reference",
            "designation",
            "history",
            "editors",
            "creation_time",
            "last_modified",
        ]

    def resolve_published(person, info):
        return person.is_public()

    def resolve_bookmarked(person, info):
        return person.is_bookmarked()


class UserType(DjangoObjectType):
    class Meta:
        model = User
        fields = [
            "id",
            "email",
            "birth_date",
            "first_name",
            "father_name",
            "grandfather_name",
            "last_name",
            "birth_place",
        ]


class CurrentUserType(graphene.ObjectType):
    """
    The currently signed-in user, used by clients to gate edit/staff actions.
    """

    id = graphene.Int()
    username = graphene.String()
    is_staff = graphene.Boolean(description="Whether the user can publish/bookmark persons")
    is_authenticated = graphene.Boolean(description="Whether a user is signed in at all")


class FontType(graphene.ObjectType):
    """
    Holds node's font data
    """

    strokeWidth = graphene.Int(description="Font stroke width in px")


class PersonSearchResult(graphene.ObjectType):
    """
    A single match returned when searching persons by name
    """

    id = graphene.Int()
    name = graphene.String(description="Person's name, including ancestors' names")


class NodeType(graphene.ObjectType):
    """
    Holds data used in visualizing person node in the tree
    """

    id = graphene.Int()
    label = graphene.String(description="name of person")
    group = graphene.String(description="can be g0, g1, .., or g4")
    title = graphene.String(description="node title, which is the string appearing as a tooltip")
    font = graphene.Field(FontType, description="Font settings")
    opacity = graphene.Float(description="0.0 (fully transparent) to 1.0")


class ConnectedNodes(graphene.ObjectType):
    """
    All nodes connected to a node (parent and children)
    """

    parent = graphene.Field(NodeType)
    children = graphene.List(NodeType)


class TreeEdge(graphene.ObjectType):
    """
    A parent -> child edge in a tree fragment, referencing nodes by ID
    """

    from_id = graphene.Int(description="Parent's ID")
    to_id = graphene.Int(description="Child's ID")


class TreePath(graphene.ObjectType):
    """
    The chain of nodes connecting an ancestor to one of their descendants
    (inclusive on both ends), plus the parent -> child edges between them
    """

    nodes = graphene.List(NodeType)
    edges = graphene.List(TreeEdge)


class DeleteInfo(graphene.ObjectType):
    descendant_count = graphene.Int()
    is_root_with_single_child = graphene.Boolean()
