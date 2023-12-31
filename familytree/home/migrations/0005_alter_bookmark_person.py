# Generated by Django 4.2.5 on 2023-09-28 17:30

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("main", "0031_rename_editor_person_editors"),
        ("home", "0004_bookmark_label_alter_bookmark_color_and_more"),
    ]

    operations = [
        migrations.AlterField(
            model_name="bookmark",
            name="person",
            field=models.OneToOneField(
                on_delete=django.db.models.deletion.CASCADE,
                to="main.person",
                verbose_name="Person",
            ),
        ),
    ]
