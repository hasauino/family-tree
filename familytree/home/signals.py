from django.db.models.signals import post_delete, post_save
from django.dispatch import receiver

from home.home_tree_generator import generate_home_tree
from home.models import Bookmark, Person


@receiver(post_save, sender=Bookmark)
@receiver(post_delete, sender=Bookmark)
def always_generate_home_tree(sender, **kwargs):
    # generate home tree only when bookmarks are changed
    generate_home_tree()


@receiver(post_save, sender=Person)
def generate_if_bookmarked(sender, **kwargs):
    if hasattr(Person, "bookmark"):
        generate_home_tree()
