from django.shortcuts import render
from home.home_tree_generator import get_tree


def index(req):
    return render(req, 'main/home.html', get_tree())
