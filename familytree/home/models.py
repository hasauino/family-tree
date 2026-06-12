from django.db import models
from django.utils.translation import gettext_lazy as _
from main.models import Person


class Tag(models.Model):
    """An admin-defined label that groups bookmarks in the home tree.
    Bookmarks placed under a tag appear as children of the tag node."""

    name = models.CharField(max_length=100, verbose_name=_("Name"))
    parent = models.ForeignKey(
        "self",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="children",
        verbose_name=_("Parent tag"),
    )
    parent_bookmark = models.ForeignKey(
        Person,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="child_tags",
        verbose_name=_("Parent bookmark"),
        help_text=_("A bookmarked person this tag should appear under, instead of another tag."),
    )
    color = models.CharField(max_length=6, null=True, blank=True, default=None, verbose_name=_("Color"))
    font_color = models.CharField(max_length=6, null=True, blank=True, default=None, verbose_name=_("Font Color"))
    font_size = models.PositiveIntegerField(null=True, blank=True, default=None, verbose_name=_("Font Size"))

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name


class HomeSettings(models.Model):
    """Singleton (pk=1) holding admin-configurable settings for the home screen."""

    center_person = models.ForeignKey(
        Person,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="+",
        verbose_name=_("Home center person"),
        help_text=_("The bookmarked person shown at the center of the home tree. Leave empty for the default."),
    )

    node_max_scale = models.FloatField(
        default=1.2,
        verbose_name=_("Max node scale"),
        help_text=_("Visual size multiplier for nodes at the root of the tree."),
    )
    node_min_scale = models.FloatField(
        default=0.5,
        verbose_name=_("Min node scale"),
        help_text=_("Visual size multiplier for the deepest (leaf) nodes."),
    )
    node_size_decay = models.FloatField(
        default=0.15,
        verbose_name=_("Node size decay"),
        help_text=_(
            "How quickly node size shrinks per generation away from the root. "
            "Higher values shrink faster; 0 makes all nodes the same size."
        ),
    )
    node_padding = models.FloatField(
        default=8.0,
        verbose_name=_("Cluster spacing"),
        help_text=_(
            "Gap (in logical pixels) kept between a node and its parent/siblings "
            "when packing the home tree. 0 packs nodes edge-to-edge."
        ),
    )
    node_spread_degrees = models.FloatField(
        default=160.0,
        verbose_name=_("Spread angle"),
        help_text=_(
            "Preferred breadth (in degrees) of the fan a node spreads its children "
            "over. Wider angles give shorter edges when a node has many children."
        ),
    )
    node_edge_factor = models.FloatField(
        default=2.0,
        verbose_name=_("Max edge length"),
        help_text=_(
            "Caps how far a child sits from its parent, as a multiple of the minimum "
            "spacing. Lower values shorten edges; when hit, the fan widens instead."
        ),
    )

    root_label = models.CharField(
        max_length=200,
        null=True,
        blank=True,
        default=None,
        verbose_name=_("Root label"),
        help_text=_("Text shown on the central root node. Leave empty to show the default tree icon."),
    )
    root_color = models.CharField(max_length=6, null=True, blank=True, default=None, verbose_name=_("Root color"))
    root_font_color = models.CharField(
        max_length=6, null=True, blank=True, default=None, verbose_name=_("Root font color")
    )
    root_font_size = models.PositiveIntegerField(null=True, blank=True, default=None, verbose_name=_("Root font size"))

    def save(self, *args, **kwargs):
        self.pk = 1
        super().save(*args, **kwargs)

    @classmethod
    def load(cls):
        obj, _created = cls.objects.get_or_create(pk=1)
        return obj

    def __str__(self):
        return "Home settings"


class Bookmark(models.Model):
    person = models.OneToOneField(Person, on_delete=models.CASCADE, verbose_name=_("Person"))
    tag = models.ForeignKey(
        Tag,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="bookmarks",
        verbose_name=_("Tag"),
    )
    color = models.CharField(max_length=6, null=True, blank=True, default=None, verbose_name=_("Color"))
    font_color = models.CharField(max_length=6, null=True, blank=True, default=None, verbose_name=_("Font Color"))
    font_size = models.PositiveIntegerField(null=True, blank=True, default=None, verbose_name=_("Font Size"))
    label = models.CharField(max_length=200, null=True, blank=True, verbose_name=_("Label"))

    def as_node(self, **args):
        value = self.person.as_node(**args)
        if "title" in value:
            del value["title"]  # remove tooltip (no need)
        value["label"] = f"*{value['label']}*"
        if len(self.person.designation) > 0:
            value["label"] += f"\n({self.person.designation})"

        if self.label is not None and len(self.label) > 0:
            value["label"] = self.label
        if self.color is not None and len(self.color) > 0:
            value["color"] = self.color

        value["font"] = dict()
        value["font"]["multi"] = "markdown"
        if self.font_size is not None:
            value["font"]["size"] = self.font_size
        if self.font_color is not None and len(self.font_color) > 0:
            value["font"]["color"] = self.font_color
        return value

    class Meta:
        ordering = ["person__pk"]

    def __str__(self):
        return self.person.__str__()
