from graphene_django import DjangoObjectType
from home.models import Bookmark


class BookmarkType(DjangoObjectType):

    class Meta:
        model = Bookmark
