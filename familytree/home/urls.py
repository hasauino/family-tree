from . import converters, views
from django.urls import path, register_converter

app_name = 'home'

register_converter(converters.NegativeIntConverter, 'negint')

urlpatterns = [
    path('', views.index, name='index'),
    path('api/bookmark_location/<int:id>/<negint:x>/<negint:y>',
         views.place_bookmark,
         name='place_bookmark'),
]
