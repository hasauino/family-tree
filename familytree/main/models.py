from collections import deque

from django.conf import settings
from django.contrib.auth.models import AbstractUser
from django.core.validators import EmailValidator
from django.db import models
from django.utils.translation import gettext_lazy as _

User = settings.AUTH_USER_MODEL

N_COLORS = 5  # number of colors in the tree color palette/theme (check main/static/tree_color_palettes.js)


class Person(models.Model):
    name = models.CharField(max_length=200, verbose_name=_("Name"))
    parent = models.ForeignKey('self',
                               on_delete=models.CASCADE,
                               null=True,
                               blank=True,
                               related_name="children",
                               verbose_name=_("Parent"))
    reference = models.CharField(
        max_length=1000,
        blank=True,
        verbose_name=_("Reference of authentication (optional)"))
    designation = models.CharField(max_length=500,
                                   blank=True,
                                   verbose_name=_("Designation (optional)"))
    history = models.CharField(
        max_length=2000,
        blank=True,
        verbose_name=_("Historical Background (optional)"))
    editors = models.ManyToManyField(User, verbose_name=_("Editor"))
    access_choices = [('public', 'public'), ('private', 'private')]
    access = models.CharField(max_length=200,
                              choices=access_choices,
                              default='public')

    def is_visible_to(self, user: User):
        """
        Checks whether the given user has view permission
        """
        if self.access == "public":
            return True
        if user.is_staff:
            return True
        return user in self.editors.all()

    def is_editable_by(self, user: User):
        """
        Checks whether the given user has edit permission
        """
        if user.is_staff:
            return True
        if self.is_public():
            return False
        editors = self.editors.all()
        if user in editors and len(editors) == 1:
            return True
        return False

    def expand(self, depth=5):
        buffer = deque([self])
        #all_persons = []
        levels = []
        while len(buffer) > 0 and depth >= 0:
            depth -= 1
            new_buffer = deque([])
            level = []
            while len(buffer) > 0:
                person = buffer.pop()
                #all_persons.append(person)
                level.append(person)
                new_buffer.extend(list(person.children.all()))
            levels.append(level)
            buffer = new_buffer
        return levels

    def get_grandfather(self):
        if self.parent is None:
            return None
        if self.parent.parent is None:
            return None
        return self.parent.parent

    def _get_father(self, parent, depth):
        try:
            if depth > 1:
                return parent.name + ' ' + self._get_father(
                    parent.parent, depth - 1)
            else:
                return ''
        except:
            return ''

    def __str__(self):
        return self.name + ' ' + self._get_father(self.parent, 6)

    def is_public(self):
        return self.access == "public"

    def is_bookmarked(self):
        return self.bookmark_set.all().exists()

    def as_node(self, user: User = None, forced_group=None):
        """
        Returns the vis.js node representation
        """
        opacity = 1.0
        if user is not None and user.is_staff:
            opacity = 1.0 if self.is_public() else 0.3
        if forced_group is None:
            group_code = f"g{(self.parent.pk if self.parent else 0) % N_COLORS}"
        else:
            group_code = f"g{forced_group}"
        return {
            "id": self.pk,
            "label": self.name,
            "group": group_code,
            "opacity": opacity,
        }

    def find_closest_parent(self, persons):
        """
        Returns closest parent among given persons list, and how far is it 
        """
        parent = self.parent
        length = 1
        while parent is not None:
            if parent in persons:
                return parent, length
            length += 1
            parent = parent.parent
        return None, -1


class User(AbstractUser):
    email = models.EmailField(
        null=True,
        blank=True,
        unique=True,
        validators=[EmailValidator(message=_("Enter a valid email address"))])
    birth_date = models.DateField(null=True,
                                  blank=False,
                                  verbose_name=_("Date of birth"))

    first_name = models.CharField(max_length=150,
                                  null=True,
                                  blank=False,
                                  verbose_name=_("First name"))
    father_name = models.CharField(max_length=150,
                                   null=True,
                                   blank=False,
                                   verbose_name=_("Father's name"))
    grandfather_name = models.CharField(max_length=150,
                                        null=True,
                                        blank=False,
                                        verbose_name=_("Grandfather's name"))
    last_name = models.CharField(max_length=150,
                                 null=True,
                                 blank=False,
                                 verbose_name=_("Last name"))

    birth_place = models.CharField(max_length=150,
                                   null=True,
                                   blank=False,
                                   verbose_name=_("Place of birth"))
