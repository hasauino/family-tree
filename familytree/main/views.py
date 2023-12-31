import json
import logging
import pathlib
import subprocess

from django.conf import settings
from django.core.exceptions import SuspiciousOperation
from django.http import HttpResponse, HttpResponseRedirect, JsonResponse
from django.shortcuts import get_object_or_404, render
from django.urls import reverse
from django.utils.translation import gettext_lazy as _
from home.home_tree_generator import generate_home_tree
from home.models import Bookmark
from main.forms import PersonForm, SettingsForm
from main.management.commands.create_db_backup import list_backups
from main.models import Person
from main.session_configs import configs

PROJECT_DIR = str(settings.PROJECT_DIR.absolute())


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
    return render(
        req, 'main/tree.html', {
            "data": json.dumps(data),
            "links": json.dumps(links),
            "main_id": person_id,
            "animation_duration": 500,
        })


def navigation(req):
    return render(req, 'main/tree_navigation.html')


def tree_from_to(req, from_id, to_id):
    matches = []

    for pk in [from_id, to_id]:
        matches.append(Person.objects.filter(pk=pk))
        if not matches[-1].exists():
            return render(req, 'main/tree_navigation.html',
                          {"error": _("Requested person does not exist")})
    from_person = matches[0].first()
    to_person = matches[1].first()
    matches = Person.objects.filter(pk=to_id)
    if not matches.exists():
        return render(req, 'main/tree_navigation.html',
                      {"error": _("Requested person does not exist")})
    to_person = get_object_or_404(Person, pk=to_id)
    levels = []
    if not from_person.is_visible_to(req.user):
        return render(req, 'main/tree_navigation.html',
                      {"error": _("Requested person does not exist")})
    person = to_person
    while person != from_person:
        if not person.is_visible_to(req.user):
            return render(req, 'main/tree_navigation.html',
                          {"error": _("Requested person does not exist")})
        if person.parent is None and person != from_person:
            return render(
                req, 'main/tree_navigation.html',
                {"error": _("Could not find a route from ancestor to child")})
        levels.extend([[person for person in person.parent.children.all()]])
        person = person.parent

    levels.append([from_person])
    all_persons = [
        person for level in levels[::-1] for person in level
        if person.is_visible_to(req.user)
    ]
    data = [p.as_node(req.user) for p in all_persons]
    links = [{
        "id": p.pk,
        "from": p.parent.pk,
        "to": p.pk,
    } for p in all_persons[1:]]
    return render(
        req, 'main/tree.html', {
            "data": json.dumps(data),
            "links": json.dumps(links),
            "main_id": to_person.pk,
            "animation_duration": 5000,
        })


def edit(req, person_id, orig_id):
    person = get_object_or_404(Person, pk=person_id)
    children = ''
    for child in person.children.all():
        if req.user.is_staff or req.user in child.editors.all():
            children += child.name + ','
    init_data = person.__dict__
    init_data["children"] = children[0:-1]
    form = PersonForm(initial=init_data)
    context = {
        'person': person,
        'orig_id': orig_id,
        'form': form,
    }
    return render(req, 'main/edit.html', context)


def save(req, orig_id, person_id):
    person = get_object_or_404(Person, pk=person_id)

    person_children = []
    for child in person.children.all():
        person_children.append(child.name)

    if req.user.is_authenticated:
        for child in req.POST['children'].split(','):
            if not child in person_children and child != '':
                new_child = Person(name=child, parent=person)

                if req.user.is_staff:
                    new_child.access = 'public'
                else:
                    new_child.access = 'private'
                new_child.save()
                new_child.editors.add(req.user)

        for child in person.children.all():
            if child.name in req.POST['children'].split(',') and not (
                    req.user in child.editors.all()):
                child.editors.add(req.user)
                child.save()

    if req.user.is_staff or req.user in person.editors.all():
        person.name = req.POST['name']
        person.designation = req.POST['designation']
        person.history = req.POST['history']

    person.save()

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
    files = list_backups()
    for file in files:
        year = file.name[-22:-18]
        month = file.name[-18:-16]
        day = file.name[-16:-14]
        hour = file.name[-14:-12]
        minutes = file.name[-12:-10]
        seconds = file.name[-10:-8]
        file_names.append(file.name)
        files_str.append(f"{year}/{month}/{day} - {hour}:{minutes}:{seconds}")
    return render(req, 'main/undo_choose.html', {
        'files_str': files_str,
        'file_names': file_names
    })


def undo_do(req, file_id):
    if req.user.is_staff:
        files = list_backups()
        chosen_file = files[file_id]
        current_db_path_rel = pathlib.Path(
            settings.DATABASES['default']['NAME'])
        root_dir = pathlib.Path(settings.BASE_DIR).parent
        current_db_path = root_dir / current_db_path_rel
        subprocess.call(f"cp {chosen_file} {current_db_path}", shell=True)
        generate_home_tree()
    return HttpResponseRedirect('/')


def tos(req):
    return render(req, 'main/tos.html')


def test(req):
    logging.info("Hello")
    return render(req, 'main/test.html')


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
    changes = [
        person for person in Person.objects.all() if person.access == 'private'
    ]
    return render(req, 'main/changes.html', {'changes': changes})
