from django.db import models
from django.utils.translation import gettext_lazy as _
from main.models import Person


class Bookmark(models.Model):
    person = models.OneToOneField(Person,
                                  on_delete=models.CASCADE,
                                  verbose_name=_("Person"))
    color = models.CharField(max_length=6,
                             null=True,
                             blank=True,
                             default=None,
                             verbose_name=_("Color"))
    font_color = models.CharField(max_length=6,
                                  null=True,
                                  blank=True,
                                  default=None,
                                  verbose_name=_("Font Color"))
    font_size = models.PositiveIntegerField(null=True,
                                            blank=True,
                                            default=None,
                                            verbose_name=_("Font Size"))
    label = models.CharField(max_length=200,
                             null=True,
                             blank=True,
                             verbose_name=_("Label"))

    def as_node(self, **args):
        value = self.person.as_node(**args)
        if "title" in value:
            del value["title"]  # remove tooltip (no need)
        value["label"] = f"*{value['label']}*\n({self.person.designation})"

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
