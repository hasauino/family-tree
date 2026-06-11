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

    def resolve_children(person, info):
        user = info.context.user
        return [c for c in person.children.all() if c.is_visible_to(user)]

    def resolve_published(person, info):
        return person.is_public()

    def resolve_bookmarked(person, info):
        return person.is_bookmarked()


class UserType(DjangoObjectType):
    profile_image_url = graphene.String(description="URL of the user's profile picture, or null if unset")

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

    def resolve_profile_image_url(user, info):
        return user.profile_image.url if user.profile_image else None


class CurrentUserType(graphene.ObjectType):
    """
    The currently signed-in user, used by clients to gate edit/staff actions
    and to populate the account/profile screen.
    """

    id = graphene.Int()
    username = graphene.String()
    is_staff = graphene.Boolean(description="Whether the user can publish/bookmark persons")
    is_authenticated = graphene.Boolean(description="Whether a user is signed in at all")
    email = graphene.String()
    first_name = graphene.String()
    last_name = graphene.String()
    father_name = graphene.String()
    grandfather_name = graphene.String()
    birth_date = graphene.Date()
    birth_place = graphene.String()
    profile_image_url = graphene.String(description="URL of the user's profile picture, or null if unset")


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


class BackupType(graphene.ObjectType):
    """
    A database restore point: a timestamped automatic backup of the sqlite DB
    that a staff user can roll the database back to.
    """

    id = graphene.Int(description="Index of the backup (newest first); pass to restoreBackup")
    label = graphene.String(description="Human-readable timestamp, e.g. '2024/01/02 - 15:14:13'")


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
    The connection between two people in the tree: every node needed to draw
    the route in context (the route itself plus the immediate siblings at each
    step), the parent -> child edges between them, and metadata describing the
    relationship.

    Two cases:
      * direct line  – one person is an ancestor of the other. ``meeting_id`` is
        the ancestor, and the two are ``from_generations``/``to_generations``
        apart (one of which is 0).
      * common root  – neither is an ancestor of the other. ``meeting_id`` is
        their lowest common ancestor; each endpoint is ``*_generations`` away
        from it.
    """

    nodes = graphene.List(NodeType)
    edges = graphene.List(TreeEdge)
    path_ids = graphene.List(
        graphene.Int,
        description="Ordered ids of the route (from -> meeting -> to) to highlight.",
    )
    meeting_id = graphene.Int(description="Id of the ancestor where the two endpoints meet.")
    from_generations = graphene.Int(description="Generations between the 'from' person and the meeting node.")
    to_generations = graphene.Int(description="Generations between the 'to' person and the meeting node.")
    is_direct = graphene.Boolean(description="True when one endpoint is an ancestor of the other.")


class DeleteInfo(graphene.ObjectType):
    descendant_count = graphene.Int()
    is_root_with_single_child = graphene.Boolean()


class HomeNode(graphene.ObjectType):
    """A node in the home radial tree.

    kind values:
      'root'     – the single virtual centre node
      'tag'      – an admin-defined label (rendered as a rounded rectangle)
      'bookmark' – a bookmarked person (rendered as a circle)
    """

    id = graphene.Int()
    kind = graphene.String()
    label = graphene.String()
    group = graphene.String()
    title = graphene.String()
    opacity = graphene.Float()
    color = graphene.String(
        description="Admin-configured override color (hex, no '#'), or null for the default palette color."
    )
    font_color = graphene.String(
        description="Admin-configured label text color (hex, no '#'), or null for the default."
    )
    font_size = graphene.Int(description="Admin-configured label font size, or null for the default.")


class NodeSizeConfig(graphene.ObjectType):
    """Admin-configurable parameters controlling how node size scales with
    depth from the global tree root (see HomeSettings)."""

    max_scale = graphene.Float(description="Visual scale of nodes at the root.")
    min_scale = graphene.Float(description="Visual scale of the deepest (leaf) nodes.")
    decay = graphene.Float(description="How quickly node size shrinks per generation away from the root.")
    padding = graphene.Float(description="Gap kept between a node disk and its parent/siblings when packing the tree.")
    spread_degrees = graphene.Float(description="Preferred fan breadth (degrees) a node spreads its children over.")
    edge_factor = graphene.Float(description="Cap on parent->child distance, as a multiple of the minimum spacing.")


class HomeTree(graphene.ObjectType):
    """Radial tree for the home screen: virtual root + tag nodes + bookmark nodes."""

    nodes = graphene.List(HomeNode)
    edges = graphene.List(TreeEdge)
    center_id = graphene.Int(
        description="ID of the home node that should be centered (admin-configurable). "
        "0 (the virtual root) if no center has been chosen."
    )
    node_size_config = graphene.Field(NodeSizeConfig, description="Admin-configurable node size scaling parameters.")


class TagType(graphene.ObjectType):
    """A lightweight tag record used by listTags and createTag."""

    id = graphene.Int()
    name = graphene.String()
    parent_id = graphene.Int(description="ID of the parent tag, or null if top-level")
