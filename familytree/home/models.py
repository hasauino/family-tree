from django.db import models
from main.models import Person
# Create your models here.


class Bookmark(models.Model):
    person = models.ForeignKey(Person, on_delete=models.CASCADE)
    x = models.IntegerField(default=0, verbose_name='إحداثي سيني')
    y = models.IntegerField(default=0, verbose_name='إحداثي صادي')

    class Meta:
        ordering = ["person__pk"]

    def __str__(self):
        return self.person.__str__()
