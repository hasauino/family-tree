import graphene
from graphene_django import DjangoObjectType
from main.models import Person, User


class PersonType(DjangoObjectType):
    published = graphene.Boolean(
        description=
        "It shows whether the person has been approved/published by a staff user"
    )
    bookmarked = graphene.Boolean(
        description=
        "It shows whether the person has been bookmarked (shown on home page) by a staff user"
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


class NodeType(graphene.ObjectType):
    """
    Holds data used in visualizing person node in the tree   
    """
    id = graphene.Int()
    label = graphene.String(description="name of person")
    group = graphene.String(description="can be g0, g1, .., or g4")
    opacity = graphene.Float(description="0.0 (fully transparent) to 1.0")


class ConnectedNodes(graphene.ObjectType):
    """
    All nodes connected to a node (parent and children)
    """
    parent = graphene.Field(NodeType)
    children = graphene.List(NodeType)
