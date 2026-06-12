from graphene_django import DjangoObjectType

from home.models import Bookmark


class BookmarkType(DjangoObjectType):
    class Meta:
        model = Bookmark
        exclude = ["tag"]  # tag FK exposed separately via homeTree / tag mutations
