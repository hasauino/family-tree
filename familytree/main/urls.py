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
    #path('test', views.test, name='test'),
    path('changes', views.changes, name='changes'),
    path('api/<str:names_str>', views.searchByName, name='searchByName'),
    path(
        'api/session_set/<str:key>/<str:value>',
        views.session_set,
        name='session_set',
    ),
    path('delete/<int:person_id>/<int:orig_id>',
         views.delete_entry,
         name='delete'),
    path('delete_my_account', views.delete_user, name='delete_user'),
    path('approve/<int:person_id>/<int:orig_id>',
         views.approve_entry,
         name='approve'),
    path('disapprove/<int:person_id>/<int:orig_id>',
         views.disapprove_entry,
         name='disapprove'),
    path('bookmark/<int:person_id>/<int:orig_id>',
         views.bookmark_entry,
         name='bookmark'),
    path('unbookmark/<int:person_id>/<int:orig_id>',
         views.unbookmark_entry,
         name='unbookmark'),
    path('<int:orig_id>/<int:person_id>/save/', views.save, name='save'),
    path('edit/<int:person_id>/<int:orig_id>', views.edit, name='edit'),
    path('<int:person_id>', views.person_tree, name='person_tree'),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT) + static(
    settings.STATIC_URL, document_root=settings.STATIC_ROOT)
