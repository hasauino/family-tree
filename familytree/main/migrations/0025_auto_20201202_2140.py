# Generated by Django 2.2.8 on 2020-12-02 21:40

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('main', '0024_auto_20201202_1959'),
    ]

    operations = [
        migrations.AlterField(
            model_name='user',
            name='first_name',
            field=models.CharField(max_length=150,
                                   null=True,
                                   verbose_name='الاسم الأول'),
        ),
        migrations.AlterField(
            model_name='user',
            name='last_name',
            field=models.CharField(max_length=150,
                                   null=True,
                                   verbose_name='العائلة'),
        ),
    ]
