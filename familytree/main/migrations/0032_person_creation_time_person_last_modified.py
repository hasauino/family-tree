# Generated by Django 4.2.5 on 2023-09-29 22:12

from django.db import migrations, models
import django.utils.timezone


class Migration(migrations.Migration):

    dependencies = [
        ("main", "0031_rename_editor_person_editors"),
    ]

    operations = [
        migrations.AddField(
            model_name="person",
            name="creation_time",
            field=models.DateTimeField(
                auto_now_add=True,
                default=django.utils.timezone.now,
                verbose_name="Date of creation",
            ),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name="person",
            name="last_modified",
            field=models.DateTimeField(
                auto_now=True, verbose_name="Date of last modification"
            ),
        ),
    ]