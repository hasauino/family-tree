import json
import pathlib
import subprocess
from datetime import datetime
from os import listdir

from django.conf import settings
from django.core.exceptions import SuspiciousOperation
from django.http import HttpResponse, HttpResponseRedirect, JsonResponse
from django.shortcuts import get_object_or_404, render
from django.urls import reverse
from django.utils.translation import gettext_lazy as _
from home.models import Bookmark
from main.forms import SettingsForm
from main.models import Person
from main.session_configs import configs
from home.home_tree_generator import generate_home_tree

PROJECT_DIR = str(settings.PROJECT_DIR.absolute())

N_COLORS = 5


def person_tree(req, person_id):
    person = get_object_or_404(Person, pk=person_id)
    grandfather = person.get_grandfather()
    levels = []
    if grandfather is not None:
        levels.append([grandfather])
    if person.parent is not None:
        levels.append([person.parent])
    levels.append([person])
    levels.extend(person.expand(depth=2)[1:])
    all_persons = [
        person for level in levels for person in level
        if person.is_visible_to(req.user)
    ]
    data = [p.as_node(req.user) for p in all_persons]
    links = [{
        "id": p.pk,
        "from": p.parent.pk,
        "to": p.pk,
    } for p in all_persons[1:]]
    return render(req, 'main/tree.html', {
        "data": json.dumps(data),
        "links": json.dumps(links),
        "main_id": person_id
    })


def edit(req, person_id, orig_id):
    person = get_object_or_404(Person, pk=person_id)

    childs = ''
    for child in person.children.all():
        if req.user.is_staff or req.user in child.editors.all():
            childs += child.name + ','

    context = {'person': person, 'orig_id': orig_id, 'childs': childs[0:-1]}
    return render(req, 'main/edit.html', context)


def save(req, orig_id, person_id):
    person = get_object_or_404(Person, pk=person_id)

    person_childs = []
    for child in person.children.all():
        person_childs.append(child.name)

    if req.user.is_authenticated:
        for child in req.POST['childs'].split(','):
            if not child in person_childs and child != '':
                new_child = Person(name=child, parent=person)

                if req.user.is_staff:
                    new_child.access = 'public'
                else:
                    new_child.access = 'private'
                new_child.save()
                new_child.editors.add(req.user)

        for child in person.children.all():
            if child.name in req.POST['childs'].split(',') and not (
                    req.user in child.editors.all()):
                child.editors.add(req.user)
                child.save()

    if req.user.is_staff or req.user in person.editors.all():
        person.name = req.POST['name']
        person.designation = req.POST['designation']
        person.history = req.POST['history']

    person.save()

    return HttpResponseRedirect(reverse('main:person_tree', args=(orig_id, )))


def delete_entry(req, person_id, orig_id):
    person = get_object_or_404(Person, pk=person_id)
    parent_id = person.parent.id
    person_id = person.id

    if req.user.is_staff or req.user in person.editors.all():
        if req.user.is_staff:
            person.delete()
        else:
            person.editors.remove(req.user)
            person.save()
            if person.access == 'private' and len(person.editors.all()) == 0:
                person.delete()

    if person_id != orig_id:
        return HttpResponseRedirect(
            reverse('main:person_tree', args=(orig_id, )))
    else:
        return HttpResponseRedirect(
            reverse('main:person_tree', args=(parent_id, )))


def approve_entry(req, person_id, orig_id):
    person = get_object_or_404(Person, pk=person_id)
    person_id = person.id

    if req.user.is_staff:
        person.access = "public"
        person.editors.add(req.user)
        person.save()

        for child in person.children.all():
            child.access = "public"
            child.editors.add(req.user)
            child.save()

    return HttpResponseRedirect(reverse('main:person_tree', args=(orig_id, )))


def disapprove_entry(req, person_id, orig_id):
    person = get_object_or_404(Person, pk=person_id)
    person_id = person.id

    if req.user.is_staff:
        person.access = "private"
        person.editors.remove(req.user)
        person.save()

        for child in person.children.all():
            child.access = "private"
            child.editors.add(req.user)
            child.save()

    return HttpResponseRedirect(reverse('main:person_tree', args=(orig_id, )))


def bookmark_entry(req, person_id, orig_id):
    person = get_object_or_404(Person, pk=person_id)

    if req.user.is_authenticated:
        bookmark = Bookmark(person=person)
        bookmark.save()

    return HttpResponseRedirect(reverse('main:person_tree', args=(orig_id, )))


def unbookmark_entry(req, person_id, orig_id):
    person = get_object_or_404(Person, pk=person_id)

    if req.user.is_authenticated:
        person.bookmark.delete()

    return HttpResponseRedirect(reverse('main:person_tree', args=(orig_id, )))


def searchByName(req, names_str):
    start = names_str.split(' ')[0]

    parents = []
    ids = []
    for p in Person.objects.filter(name__startswith=start):
        if req.user in p.editors.all(
        ) or p.access == "public" or req.user.is_staff:
            if names_str == str(p)[0:len(names_str)]:
                parents.append(str(p))
                ids.append(p.id)
                if len(parents) > 5:
                    break

    return JsonResponse({'parents': parents, 'ids': ids})


def undo_choose(req):
    files_str = []
    file_names = []
    files = sorted(settings.DB_BACKUP_DIR.glob("*.sqlite3"), reverse=True)
    for file in files:
        year = file.name[6:10]
        month = file.name[10:12]
        day = file.name[12:14]
        hour = file.name[14:16]
        minutes = file.name[16:18]
        seconds = file.name[18:20]
        file_names.append(file.name)
        files_str.append(f"{year}/{month}/{day} - {hour}:{minutes}:{seconds}")
    return render(req, 'main/undo_choose.html', {
        'files_str': files_str,
        'file_names': file_names
    })


def undo_do(req, file_id):
    if req.user.is_staff:
        files = list(sorted(settings.DB_BACKUP_DIR.glob("*.sqlite3"),
                            reverse=True))
        chosen_file = files[file_id]
        current_db_path_rel = pathlib.Path(settings.DATABASES['default']['NAME'])
        root_dir = pathlib.Path(settings.BASE_DIR).parent
        current_db_path = root_dir / current_db_path_rel
        subprocess.call(f"cp {chosen_file} {current_db_path}", shell=True)
        generate_home_tree()
    return HttpResponseRedirect('/')


def get_client_ip(request):
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        ip = x_forwarded_for.split(',')[0]
    else:
        ip = request.META.get('REMOTE_ADDR')
    return ip


def tos(req):
    return render(req, 'main/tos.html')


def test(req):
    return render(req, 'main/test.html')


def session_set(req, key, value):
    if key not in configs:
        raise SuspiciousOperation()
    req.session[key] = value
    return JsonResponse({key: value})


def settingsPanel(req):
    if req.user.is_authenticated:
        if req.method == 'POST':
            form = SettingsForm(req.POST)
            if form.is_valid():
                req.user.first_name = req.POST['first_name']
                req.user.father_name = req.POST['father_name']
                req.user.grandfather_name = req.POST['grandfather_name']
                req.user.last_name = req.POST['last_name']
                req.user.birth_date = req.POST['birth_date']
                req.user.birth_place = req.POST['birth_place']
                req.user.save()

                return HttpResponseRedirect('/')

        else:
            form = SettingsForm(instance=req.user)

        return render(req, 'main/settings.html', {'form': form})

    else:

        return HttpResponse(_("You are not logged in!"))


def delete_user(req):
    if req.user.is_authenticated:
        req.user.delete()
    return HttpResponseRedirect('/')


def changes(req):
    changes = []
    for person in Person.objects.all():
        if person.access == 'private':
            changes.append(person)
    return render(req, 'main/changes.html', {'changes': changes})
