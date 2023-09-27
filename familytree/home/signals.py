from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from home.models import Bookmark
from home.home_tree_generator import generate_home_tree


@receiver(post_save, sender=Bookmark)
@receiver(post_delete, sender=Bookmark)
def my_callback(sender, **kwargs):
    # generate home tree only when bookmarks are changed
    generate_home_tree()
