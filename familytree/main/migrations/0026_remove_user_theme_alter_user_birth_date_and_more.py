# Generated by Django 4.2.5 on 2023-09-17 15:30

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("main", "0025_auto_20201202_2140"),
    ]

    operations = [
        migrations.RemoveField(
            model_name="user",
            name="theme",
        ),
        migrations.AlterField(
            model_name="user",
            name="birth_date",
            field=models.DateField(null=True, verbose_name="Date of birth"),
        ),
        migrations.AlterField(
            model_name="user",
            name="birth_place",
            field=models.CharField(
                max_length=150, null=True, verbose_name="Place of birth"
            ),
        ),
        migrations.AlterField(
            model_name="user",
            name="father_name",
            field=models.CharField(
                max_length=150, null=True, verbose_name="Father's name"
            ),
        ),
        migrations.AlterField(
            model_name="user",
            name="first_name",
            field=models.CharField(
                max_length=150, null=True, verbose_name="First name"
            ),
        ),
        migrations.AlterField(
            model_name="user",
            name="font_size",
            field=models.IntegerField(default=100, verbose_name="Font size"),
        ),
        migrations.AlterField(
            model_name="user",
            name="grandfather_name",
            field=models.CharField(
                max_length=150, null=True, verbose_name="Grandfather's name"
            ),
        ),
        migrations.AlterField(
            model_name="user",
            name="last_name",
            field=models.CharField(max_length=150, null=True, verbose_name="Last name"),
        ),
    ]
