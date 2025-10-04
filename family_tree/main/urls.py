from django.conf import settings
from django.conf.urls.static import static
from django.urls import path
from django.views.decorators.csrf import csrf_exempt
from graphene_django.views import GraphQLView

from . import views

app_name = 'main'

urlpatterns = [
    path("graphql", csrf_exempt(GraphQLView.as_view(graphiql=settings.DEBUG))),
    path('settings', views.settingsPanel, name='settingsPanel'),
    path('undo/<int:file_id>', views.undo_do, name='undo_do'),
    path('undo', views.undo_choose, name='undo_choose'),
    path('tos', views.tos, name='tos'),
    path('test', views.test, name='test'),
    path('changes', views.changes, name='changes'),
    path('api/<str:names_str>', views.searchByName, name='searchByName'),
    path('delete_my_account', views.delete_user, name='delete_user'),
    path('<int:orig_id>/<int:person_id>/save/', views.save, name='save'),
    path('edit/<int:person_id>/<int:orig_id>', views.edit, name='edit'),
    path('<int:person_id>', views.person_tree, name='person_tree'),
    path('<int:from_id>/<int:to_id>', views.tree_from_to, name='tree_from_to'),
    path('navigation', views.navigation, name='navigation'),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT) + static(
    settings.STATIC_URL, document_root=settings.STATIC_ROOT)
